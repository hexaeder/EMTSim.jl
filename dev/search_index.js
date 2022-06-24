var documenterSearchIndex = {"docs":
[{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"EditURL = \"https://github.com/hexaeder/EMTSim.jl/blob/main/examples/slack_load.jl\"","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"using EMTSim\nusing BlockSystems\nusing ModelingToolkit\nusing NetworkDynamics\nusing Graphs\nusing OrdinaryDiffEq\nusing DiffEqCallbacks\nusing SteadyStateDiffEq\nusing Plots\nusing Unitful\nusing CSV\nusing DataFrames","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"Constants and unit stuff.","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"ω0    = 2π*50u\"rad/s\"\nSbase = 300u\"MW\"\nVbase = 110u\"kV\" #* sqrt(2/3)\nIbase = Sbase/(Vbase )#* √3) # why the √3 ?\nCbase = Ibase/Vbase\nLbase = Vbase/Ibase\nRbase = (Vbase^2)/Sbase\n\nRline = 1u\"Ω\" / Rbase           |> u\"pu\"\nPload = 300u\"MW\" / Sbase        |> u\"pu\"\nRload = (1u\"pu\")^2 / Pload      |> u\"pu\" # R=U^2/P\nCline = (2e-6)u\"F\" / Cbase      |> u\"s\"\nLline = (1/100π)u\"H\" / Lbase    |> u\"s\"\n\nnothing#hide","category":"page"},{"location":"generated/slack_load/#Slack-Bus","page":"slack_load","title":"Slack Bus","text":"","category":"section"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"@variables t u_d(t) u_q(t)\ndt = Differential(t)\n\nslackblock = IOBlock([dt(u_d) ~ 0, dt(u_q) ~ 0], [], [u_d, u_q]; name=:slack)","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"create ODE Vertex from this block","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"slack = ODEVertex(slackblock)\nnothing#hide","category":"page"},{"location":"generated/slack_load/#R-Load","page":"slack_load","title":"R Load","text":"","category":"section"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"@variables t i_d(t) i_q(t)\n@parameters u_d(t) u_q(t) R\nloadblock = IOBlock([i_d ~ -1/R * u_d,\n                     i_q ~ -1/R * u_q],\n                    [u_d, u_q], [i_d, i_q],\n                    name=:load)","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"The load is used as a current source in a BusBar","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"busblock = BusBar(loadblock; name=:loadbus)\nbusblock = set_p(busblock, Dict(:C=>ustrip(u\"s\", Cline), :ω0=>ustrip(u\"rad/s\", ω0)))","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"The BusBar block can be used to create an ODE Vertex","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"load = ODEVertex(busblock, [:load₊R])\n\nnothing#hide","category":"page"},{"location":"generated/slack_load/#ODE-edge-for-the-RL-Line","page":"slack_load","title":"ODE edge for the RL Line","text":"","category":"section"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"@variables t i_d(t) i_q(t)\n@parameters u_d_src(t) u_q_src(t) u_d_dst(t) u_q_dst(t) R L ω\n\nlineblock = IOBlock([dt(i_d) ~  ω * i_q  - R/L * i_d + 1/L*(u_d_src - u_d_dst),\n                     dt(i_q) ~ -ω * i_d  - R/L * i_q + 1/L*(u_q_src - u_q_dst)],\n                    [u_d_src, u_q_src, u_d_dst, u_q_dst],\n                    [i_d, i_q],\n                    name=:RLLine)\nlineblock = set_p(lineblock, Dict(:R=>NoUnits(Rline), :L=>ustrip(u\"s\", Lline), :ω=>ustrip(u\"rad/s\", ω0)))","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"This block can be used to create an ODEEdge","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"edge = ODEEdge(lineblock)\n\nnothing#hide","category":"page"},{"location":"generated/slack_load/#Set-up-the-network","page":"slack_load","title":"Set up the network","text":"","category":"section"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"g = SimpleGraph(2)\nadd_edge!(g, 1, 2)\nnd = network_dynamics([slack, load], edge, g)\n\nnothing#hide","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"we use SteadyStateDiffeq to find the steady state","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"uguess = zeros(length(nd.syms))\nuguess[1] = 1.0 # set the d component of the slack to 1 from the beginning\np = ([0, NoUnits(Rload)], nothing)\nssprob = SteadyStateProblem(nd, uguess, p)\nu0 = solve(ssprob, DynamicSS(AutoTsit5(Rosenbrock23())))\n\nnothing#hide\n# Simulation","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"We simulate a disconnection of the load at t=0.1 s","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"tspan = (0.0, 0.2)\ncb = PresetTimeCallback(0.1, integrator -> integrator.p = ([0, Inf], nothing))\nprob = ODEProblem(nd, u0, tspan, p; callback=cb)\nsol = solve(prob, Tsit5())\n\n# plot the dq voltage of node 2\n# plot(sol, vars=[3,4]; xlims=(0.095, 0.124))","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"Transformation of the results back to a,b,c frame","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"a,b,c = Tdqinv(sol.t, sol[3,:], sol[4,:])\nnothing#hide","category":"page"},{"location":"generated/slack_load/#Comparison-with-power-factory-results","page":"slack_load","title":"Comparison with power factory results","text":"","category":"section"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"Read the Power Facory data and plot for reference","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"V_base is RMS phase-phase voltage.","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"V_star = frac1sqrt3 *  V_base\nhatV = sqrtfrac23 * V_base","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"Therefore, i have to multiply the a, b and c results by sqrt(3/2)","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"df = CSV.read(joinpath(dirname(pathof(EMTSim)), \"..\", \"data\",\"PowerFactory\", \"Test_EMT.csv\"), DataFrame, skipto=3,\n              header=[:t, :u_1_a, :u_1_b, :u_1_c, :u_2_a, :u_2_b, :u_2_c])\n\nxlims = (0.099,0.124)\nplot(sol.t, a.*sqrt(3/2); label=\"u_2_a\", xlims)\nplot!(df.t, df.u_2_a; label=\"PowerFactory A\")\n\nplot!(sol.t, b.*sqrt(3/2); label=\"u_2_b\")\nplot!(df.t, df.u_2_b; label=\"PowerFactory B\")\n\nplot!(sol.t, c.*sqrt(3/2); label=\"u_2_c\")\nplot!(df.t, df.u_2_c; label=\"PowerFactory C\")","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"... lets have a closer look","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"xlims!(0.0995,0.105)","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"","category":"page"},{"location":"generated/slack_load/","page":"slack_load","title":"slack_load","text":"This page was generated using Literate.jl.","category":"page"},{"location":"","page":"Home","title":"Home","text":"CurrentModule = EMTSim","category":"page"},{"location":"#EMTSim","page":"Home","title":"EMTSim","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for EMTSim.","category":"page"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [EMTSim]","category":"page"},{"location":"#NetworkDynamics.ODEEdge","page":"Home","title":"NetworkDynamics.ODEEdge","text":"Conventions: (Anti-)symmetric lines:\n\ninputs:   u_d_src, u_q_src, u_d_dst, u_q_dst\noutputs:  i_d, i_q\ncurrent direction is defined from src to dst\ndst node will receive -i_d, -i_q\n\nAsymmetric lines:\n\ninputs:   u_d_src, u_q_src, u_d_dst, u_q_dst\noutputs:  i_d_src, i_q_src, i_d_dst, i_q_dst\nnot yet implemented. might by tricky with fidutial...\n\n\n\n\n\n","category":"type"},{"location":"#EMTSim.subscript-Union{Tuple{T}, Tuple{T, Int64}} where T<:Union{AbstractString, Symbol}","page":"Home","title":"EMTSim.subscript","text":"subscript(s, i)\n\nAppend symbol or string s with a integer subscript.\n\n\n\n\n\n","category":"method"}]
}