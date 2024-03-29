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

export fixdiv
function fixdiv(A)
    for idx in eachindex(A)
        if A[idx] isa SymbolicUtils.Div
            A[idx] = eval(Meta.parse(repr(A[idx])))
        end
    end
    A = BlockSystems.narrow_type(A)
end

export ctrb, obsv
function ctrb(A, B)
    N, N2 = size(A)
    @assert N==N2
    C = B
    for i in 1:N-1
        C = hcat(C, (A^i) * B)
    end
    return C
end

function obsv(A, C)
    N, N2 = size(A)
    @assert N==N2
    O = C
    for i in 1:N-1
        O = vcat(O, C * (A^i))
    end
    return O
end

export @labelled
macro labelled(ex)
    qn = _find_quot_node(ex)
    isnothing(qn) && error("Did not find symbol.")

    if Meta.isexpr(ex, :call)
        pushfirst!(ex.args, ex.args[begin])
        ex.args[2] = Expr(:parameters, Expr(:kw, :label, :(string($qn))))
    else
        error("Malformed expresseion")
    end
    esc(ex)
end

function _find_quot_node(ex)
    if ex isa QuoteNode
        return ex
    elseif ex isa Expr
        for arg in ex.args
            node = _find_quot_node(arg)
            if node isa QuoteNode
                return node
            end
        end
    end
    return nothing
end

export u0guess
u0guess(nd::ODEFunction) = u0guess.(nd.syms)
function u0guess(s::Symbol)
    s = string(s)
    if occursin(r"^u_r", s)
        1.0
    elseif occursin(r"^A", s)
        1.0
    elseif occursin(r"^MfIf", s)
        sqrt(2/3) * 1/(2π*50)
    else
        0.0
    end
end
