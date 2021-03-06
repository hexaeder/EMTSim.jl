using Unitful

# define perunit as unit
@unit pu "p.u." PerUnit 1 false
Unitful.register(EMTSim)
function __init__()
    Unitful.register(EMTSim)
end

"""
    subscript(s, i)

Append symbol or string `s` with a integer subscript.
"""
function subscript(s::T, i::Int) where T <: Union{Symbol, AbstractString}
    @assert 0≤i≤9 "subscript only supported from 0..9"
    Symbol(s, Char(0x02080 + i))
end

# dq transformations
export Tdq, Tdqinv

Tdq(δ) = √(2/3)*[ cos(δ)  cos(δ-2pi/3)  cos(δ+2pi/3)
                 -sin(δ) -sin(δ-2pi/3) -sin(δ+2pi/3)]

Tdqinv(δ) = √(2/3)* [cos(δ)       -sin(δ)
                     cos(δ-2pi/3) -sin(δ-2pi/3)
                     cos(δ+2pi/3) -sin(δ+2pi/3)]

Tdq(t, a, b, c; ω=2π*50) = Tdq(ω*t)*[a, b, c]
function Tdqinv(t, d, q; ω=2π*50)
    N = length(t)
    a = similar(d)
    b = similar(d)
    c = similar(d)

    for i in 1:N
        a[i], b[i], c[i] = Tdqinv(ω*t[i])*[d[i], q[i]]
    end

    return a, b, c
end
