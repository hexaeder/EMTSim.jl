#=
# Experiment on virtual inertia
=#

## This parameter set was used in a small EMT experiment with
ω0    = 2π*50u"rad/s"
Sbase = 5u"kW"
Vbase = 230u"V"
Ibase = Sbase/(Vbase) |> u"A"
Cbase = Ibase/Vbase
Lbase = Vbase/Ibase
Rbase = (Vbase^2)/Sbase

## values from 10km
Rline = 0.354u"Ω" / Rbase       |> u"pu"
Lline = 350e-6u"H" / Lbase      |> u"s"
Cline = 2*(12e-6)u"F" / Cbase   |> u"s"

using EMTSim
using BlockSystems
using NetworkDynamics
using Graphs
using OrdinaryDiffEq
using DiffEqCallbacks
using SteadyStateDiffEq
using Plots
import CairoMakie
using GraphMakie
using Unitful

NODES = 5

#=
Topology
```
                      conv
                    3    N-1
  second ctrl 1 o---o- ⋯ -o---o 2 load
```
=#

function solvesystem(;τ_P=0.9e-6, τ_Q=0.9e-6, K_P=1.0, K_Q=1.0, τ_sec=1, tmax=5, τ_load=0.001, n=NODES)
    # lossless RMS Pi Model Line
    rmsedge = RMSPiLine(R=0, L=ustrip(Lline), C1=ustrip(Cline/2), C2=ustrip(Cline/2))

    # conv = ODEVertex(EMTSim.PT1Source(;τ=0.001),
    conv = ODEVertex(EMTSim.PerfectSource(),
                     EMTSim.DroopControl(;Q_ref=0,
                                         V_ref=1, ω_ref=0,
                                         τ_P, K_P,
                                         τ_Q, K_Q))

    # second_ctrl = SecondaryControlCS_PI(; EMT=false, Ki=Ki_sec, Kp=Kp_sec)
    second_ctrl = SecondaryControlCS_PT1(; EMT=false, τ_cs=τ_load, τ=τ_sec)
    second_ctrl.f.params

    load = PT1PLoad(;τ=τ_load)

    # make sure that we defined all parameters but P_ref for all of the nodes
    load.f.params # P_ref
    conv.f.params # P_ref
    second_ctrl.f.params # P_ref

    g = SimpleGraph(n)
    add_edge!(g, 1, 3)
    add_edge!(g, n, 2)
    for i in 3:n-1
        add_edge!(g, i, i+1)
    end

    Nconv = n-2

    nd = network_dynamics([second_ctrl, load, [conv for i in 1:Nconv]...], rmsedge, g)

    uguess = u0guess(nd)
    nd.syms .=> uguess

    pref = [0, -1.0, [1/Nconv for i in 1:Nconv]...]
    p = (pref, nothing)
    ssprob = SteadyStateProblem(nd, uguess, p)
    u0 = solve(ssprob, DynamicSS(Rodas4()))

    nd.syms .=> round.(u0; digits=2)

    function affect(integrator)
        pref_new = copy(pref)
        pref_new[1] += .1 # step up secondary control
        pref_new[2] -= .1 # step down load
        integrator.p = (pref_new, nothing)
        auto_dt_reset!(integrator)
    end
    cb = PresetTimeCallback(0.1, affect)

    tspan = (0.0, tmax)
    prob = ODEProblem(nd, u0, tspan, p; callback=cb)
    sol = solve(prob, Rodas4(), dtmax=0.01)
end

plotsym(sol::ODESolution, sym, nodes=1:NODES; mean=false) = plotsym!(plot(), sol, sym, nodes; mean)
plotsym!(sol::ODESolution, sym, nodes=1:NODES; mean=false) = plotsym!(Plots.current(), sol, sym, nodes; mean)
function plotsym!(p::Plots.Plot, sol::ODESolution, sym, nodes=1:NODES; mean=false)
    function names(i)
        if i==1
            " @ secondary control"
        elseif i==2
            " @ load"
        else
            " @ conv$(i-2)"
        end
    end
    if mean
        plot!(p, meanseries(sol, nodes, sym); label=string(sym)*" mean")
    else
        for i in nodes
            try
                plot!(p, timeseries(sol, i, sym); label=string(sym)*names(i))
            catch
                @warn "Could not create timeseries for $sym on node $i. Skipped!"
            end
        end
    end
    p
end

function powerloss(sol)
    t, P = timeseries(sol, 1, :Pmeas)
    tidx = findfirst(x->x ≥ 0.1, t)
    t = t[tidx:end]
    P = P[tidx:end]
    Punder = 0.1 .- P
    sum(diff(t) .* Punder[1:end-1])
end

# First we start with with very small values of τ_P and τ_Q (i.e. low invertia)
sol = solvesystem(τ_P=1e-6, τ_Q=1e-6, K_P=1.0, K_Q=1.0, τ_sec=0.8, tmax=5);
p = plotsym(sol, :Pmeas)

# lets have a look at different values for the droop term K
# EMTSim.TS_DTMAX 0.0005
EMTSim.set_ts_dtmax(0.0005)
plts = Any[]
storage = Vector{Float64}[]
ploss = Float64[]
τ = 0.05
for K in [0.5, 1.0, 1.5, 2.0]
    sol = solvesystem(τ_P=τ, τ_Q=τ, K_P=K, K_Q=K, τ_sec=1, tmax=4);
    p1 = plotsym(sol, :Pmeas, [3:NODES...])
    # ylims!(0.95,1.45)
    p2 = plotsym(sol, :imag, 3:NODES)
    p3 = plotsym(sol, :ωmeas, [3:NODES...,1])
    xlims!(p3, 0.09, 0.2)
    ylims!(p3, -0.12, 0.01)
    title!(p1, "K = $K")
    push!(plts, plot(p1, p2, p3, layout=(1,:)))
    push!(storage, needed_storage(sol, 3:NODES))
    push!(ploss, powerloss(sol))
end
plot(plts..., layout=(:,1), size=(1600,1000))
storage
ploss
((sum.(storage) .- ploss)./ploss)*100

#=
For a fixed K, look at different τ
=#
plts = Any[]
storage = Vector{Float64}[]
ploss = Float64[]
K = 2.0
for τ in [1.0, 0.1, 0.01, 0.001]
    sol = solvesystem(τ_P=τ, τ_Q=τ, K_P=K, K_Q=K, τ_sec=1, tmax=4);
    p1 = plotsym(sol, :Pmeas, [3:NODES...])
    # ylims!(0.95,1.45)
    p2 = plotsym(sol, :imag, [3:NODES...])
    # ylims!(0.7,0.95)
    p3 = plotsym(sol, :ωmeas, [3:NODES...])
    # xlims!(p3, 0.09, 0.2)
    title!(p1, "τ = $τ")
    push!(plts, plot(p1, p2, p3, layout=(1,:)))
    push!(storage, needed_storage(sol, 3:NODES))
    push!(ploss, powerloss(sol))
end
plot(plts..., layout=(:,1), size=(1600,800))
storage
ploss
((sum.(storage) .- ploss)./ploss)*100


#=
K and τ simultaniously
=#
plts = Any[]
for K in [0.5, 1.0, 1.5, 2.0]
    innerplts = Any[]
    for τ in [0.2, 0.1, 0.01]
        τ = M*K
        sol = solvesystem(τ_P=τ, τ_Q=τ, K_P=K, K_Q=K, τ_sec=1, tmax=2);
        # p = plotsym(sol, :Pmeas, [3:NODES...])
        title!(p,"K=$K  τ = $τ")
        push!(innerplts, p)
    end
    push!(plts, plot(innerplts..., layout=(1,:)))
end
plot(plts..., layout=(:,1), size=(1600,1000))

#=
Keep rocof constant?
=#
plts = Any[]
for K in [0.5, 1.0, 1.5, 2.0]
    innerplts = Any[]
    for M in [0.1, 0.2, 0.3]
        τ = M*K
        sol = solvesystem(τ_P=τ, τ_Q=τ, K_P=K, K_Q=K, τ_sec=1, tmax=2);
        p = plotsym(sol, :rocof, [3:NODES...])
        # p = plotsym(sol, :ωmeas, [3:NODES...])

        # t, ωmean = timeseries(sol, 3, :ωmeas)
        # for i in 4:NODES
        #     _, ω = timeseries(sol, i, :ωmeas)
        #     ωmean += ω
        # end
        # ωmean = ωmean / (NODES-2)
        # plot!(t, ωmean, width=5)

        title!(p,"K=$K  M=$M  τ=$τ")
        push!(innerplts, p)
    end
    push!(plts, plot(innerplts..., layout=(1,:)))
end
plot(plts..., layout=(:,1), size=(1600,1000))

#=
Theoretical value for storage needs (what is lost until secondary control kicks in)
=#
int = Any[]
for τ in [1.3, 0.1, 0.01, 0.001]
    K=0.8
    sol = solvesystem(τ_P=τ, τ_Q=τ, K_P=K, K_Q=K, Ki_sec=1, Kp_sec=0, tmax=10.0);
    t, P = timeseries(sol, 1, :Pmeas)
    Pover = 0.5 .- P
    fidx = findfirst(x->x>0.1, t)
    t = t[fidx:end]
    Pover = Pover[fidx:end]
    push!(int,  sum(diff(t) .* Pover[1:end-1]))
end

p = plot(legend=:bottomright)
for τ in [1.3, 0.1, 0.01, 0.001]
    K=0.8
    sol = solvesystem(τ_P=τ, τ_Q=τ, K_P=K, K_Q=K, Ki_sec=1, Kp_sec=0, tmax=20.0);
    plotsym!(p, sol, :Pmeas, 1)
end
current()

p = plot(legend=:bottomright)
for τ in [1.3, 0.1, 0.01, 0.001]
    K=0.8
    sol = solvesystem(τ_P=τ, τ_Q=τ, K_P=K, K_Q=K, Ki_sec=1, Kp_sec=0, tmax=20.0);
    plotsym!(p, sol, :ωmeas, 1)
end
current()

plotsym(sol, :ωmeas, 3:NODES)
plotsym!(sol, :ωmeas, 3:NODES, mean=true)
NADIR(sol, 3:NODES)

plotsym(sol, :rocof, 3:NODES)
plotsym!(sol, :rocof, 3:NODES, mean=true)
ROCOF(sol, 3:NODES)