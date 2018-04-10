import Mill: DataNode, lastcat
abstract type AbstractReflector end;
"""
	struct ExtractScalar{T}
		datatype::Type{T}
		c::T
		s::T
	end

	extract a scalar value and center. If `T` is of type number, it is centered by first subtracting c and then
	multiplying that with s. 
"""
struct ExtractScalar{T,V} <: AbstractReflector
	datatype::Type{T}
	c::V
	s::V
end

ExtractScalar(::Type{T}) where {T<:Number} = ExtractScalar(T,T(0),T(1))
ExtractScalar(::Type{T}) where {T} = ExtractScalar(T,nothing,nothing)
dimension(s::ExtractScalar) = 1
(s::ExtractScalar{T,V})(v) where {T<:Number,V}						= s.s .* (reshape([s.datatype(v)],(1,1)) .- s.c)
(s::ExtractScalar{T,V} where {V,T<:Number})(v::String)   = s(parse(s.datatype,v))
(s::ExtractScalar{T,V} where {V,T<:AbstractString})(v)   = DataNode(reshape([v],(1,1)))
#handle defaults
(s::ExtractScalar{T,V})(v::S) where {T<:Number,V,S<:Void}= reshape([0],(1,1))
(s::ExtractScalar{T,V})(v::S) where {T<:AbstractString,V,S<:Void} = DataNode(reshape([""],(1,1)))

"""
	struct ExtractCategorical{T}
		datatype::Type{T}
		items::T
	end

	Convert scalar to one-hot encoded array.
"""

struct ExtractCategorical{T,I<:Vector} <: AbstractReflector
	datatype::Type{T}
	items::I
end

ExtractCategorical(items) = ExtractCategorical(Float32,items)
ExtractCategorical(T,s::Entry) = ExtractCategorical(T,sort(collect(keys(s.counts))))
ExtractCategorical(T,s::UnitRange) = ExtractCategorical(T,collect(s))
dimension(s::ExtractCategorical)  = length(s.items)
function (s::ExtractCategorical)(v) 
	x = zeros(s.datatype,length(s.items),1)
	i = findfirst(s.items,v)
	if i > 0
		x[i] = 1
	end
	x
end

(s::ExtractCategorical)(v::V) where {V<:Void} =  zeros(s.datatype,length(s.items))

"""
	struct ExtractArray{T}
		item::T
	end

	convert array of values to one bag of values converted with `item`. Note that in order the function to work properly,
	calling `item` on a single item has to return Matrix.

```juliadoctest
julia> sc = ExtractArray(ExtractCategorical(Float32,2:4))
julia> sc([2,3,1,4]).data
3×4 Array{Float32,2}:
 1.0  0.0  0.0  0.0
 0.0  1.0  0.0  0.0
 0.0  0.0  0.0  1.0

```

```juliadoctest
julia> sc = ExtractArray(ExtractScalar())
julia> sc([2,3,4]).data
 2.0  3.0  4.0
```
"""

struct ExtractArray{T} <: AbstractReflector
	item::T
end

dimension(s::ExtractArray)  = dimension(s.item)
(s::ExtractArray)(v::V) where {V<:Void} = DataNode(lastcat(s.item.([nothing])...),[1:1])
(s::ExtractArray)(v) = isempty(v) ? s(nothing) : DataNode(lastcat(s.item.(v)...),[1:length(v)])

"""
	struct ExtractBranch
		vec::Dict{String,Any}
		other::Dict{String,Any}
	end

	extracts all items in `vec` and in `other` and return them as a DataNode.
"""
struct ExtractBranch{S,V} <: AbstractReflector
	vec::S
	other::V
	function ExtractBranch(v::S,o::V) where {S<:Union{Dict,Void},V<:Union{Dict,Void}} 
		v = (v == nothing || isempty(v)) ? nothing : v
		o = (o == nothing || isempty(o)) ? nothing : o
		new{typeof(v),typeof(o)}(v,o)
	end
end


(s::ExtractBranch)(v::V) where {V<:Void} = s(Dict{String,Any}())

function (s::ExtractBranch{S,V})(v::Dict) where {S<:Dict,V<:Dict}
	x = vcat(map(k -> s.vec[k](get(v,k,nothing)),keys(s.vec))...)
	o = map(k -> s.other[k](get(v,k,nothing)), keys(s.other))
	data = tuple([x,o...]...)
	DataNode(data,nothing,nothing)
end

function (s::ExtractBranch{S,V})(v::Dict) where {S<:Dict,V<:Void}
	x = vcat(map(k -> s.vec[k](get(v,k,nothing)),keys(s.vec))...)
	DataNode(x,nothing,nothing)
end

function (s::ExtractBranch{S,V})(v::Dict) where {S<:Void,V<:Dict}
	x = map(k -> s.other[k](get(v,k,nothing)), keys(s.other))
	x = (length(x) == 1) ? x[1] : tuple(x...)
	DataNode(x,nothing,nothing)
end