using Test
using EMTSim
using BlockSystems
using Plots
using OrdinaryDiffEq

@testset "ReducedPLL" begin
    pll = Components.ReducedPLL()
    pll = set_p(pll; ω_lp=1.32 * 2π*50, Kp=20.0, Ki=2.0)

    p2c = Components.Polar2Cart()
    blk = @connect p2c.(x,y) => pll.(u_r, u_i) outputs=:remaining

    blk = set_input(blk, :mag => 1.0)
    @variables t
    blk = set_input(blk, :arg => 0)

    f = ODEFunction(blk)
    u0 = rand(length(f.syms))
    tspan = (0,10)
    prob = ODEProblem(f,u0,tspan)
    sol = solve(prob, Rodas4())
    plot(sol)

    # test that angle is close to n*π
    @test abs(rem(sol[end][1], π)) < 0.01
    # test that frequency is near zero
    @test sol[end][2] < 1e-4


    # more complicated test
    pll = Components.ReducedPLL()
    pll = set_p(pll; ω_lp=1.32 * 2π*50, Ki=20.0, Kp=2.0)
    p2c = Components.Polar2Cart()
    blk = @connect p2c.(x,y) => pll.(u_r, u_i) outputs=:remaining
    blk = set_input(blk, :mag => 1.0)
    @variables t
    blk = set_input(blk, :arg => 0.1*sin(0.5*t))

    f = ODEFunction(blk)
    u0 = zeros(length(f.syms))
    f.syms .=> u0
    tspan = (0,50)
    prob = ODEProblem(f,u0,tspan)
    sol = solve(prob, Rodas4())

    plot(sol.t, sol[:ω_pll]; label="tracked freq")
    plot!(t->0.1*cos(0.5*t)*0.5; label="input freq")
    ylims!(-.1,.1)

    plot(sol.t, sol[:δ_pll]; label="tracked arg")
    plot!(t->0.1*sin(0.5*t); label="input arg")
end

@testset "KauraPLL" begin
    pll = Components.KauraPLL()
    pll = set_p(pll; ω_lp=500, Kp=20, Ki=2)

    p2c = Components.Polar2Cart()
    blk = @connect p2c.(x,y) => pll.(u_r, u_i) outputs=:remaining

    blk = set_input(blk, :mag => 1.0)
    @variables t
    blk = set_input(blk, :arg => 0)

    f = ODEFunction(blk)
    u0 = rand(length(f.syms))
    tspan = (0,10)
    prob = ODEProblem(f,u0,tspan)
    sol = solve(prob, Rodas4())
    plot(sol)

    # test that angle is close to n*π
    @test abs(rem(sol[end][1], π)) < 0.01
    # test that frequency is near zero
    @test sol[end][2] < 1e-4


    # more complicated test
    pll = Components.KauraPLL()
    pll = set_p(pll; ω_lp=500, Kp=20., Ki=2)
    p2c = Components.Polar2Cart()
    blk = @connect p2c.(x,y) => pll.(u_r, u_i) outputs=:remaining
    blk = set_input(blk, :mag => 1.0)
    @variables t
    blk = set_input(blk, :arg => 0.1*sin(0.5*t))

    f = ODEFunction(blk)
    u0 = zeros(length(f.syms))
    u0[3] = 1.0
    f.syms .=> u0
    tspan = (0,50)
    prob = ODEProblem(f,u0,tspan)
    sol = solve(prob, Rodas4())

    plot(sol.t, sol[:ω_pll]; label="tracked freq")
    plot!(t->0.1*cos(0.5*t)*0.5; label="input freq")
    ylims!(-.1,.1)

    plot(sol.t, sol[:δ_pll]; label="tracked arg")
    plot!(t->0.1*sin(0.5*t); label="input arg")
end

@testest "PT1CurrentSource" begin
    cs = Components.PT1CurrentSource()

    p2c = Components.Polar2Cart()
    blk = @connect p2c.(x,y) => cs.(u_r, u_i) outputs=:remaining

    blk = set_p(blk; τ=0.01, P_ref=1, mag=1)

    @variables t
    blk = set_input(blk, :arg => 0.5*(t>1))

    f = ODEFunction(blk)
    u0 = zeros(length(f.syms))
    tspan = (0,2)
    prob = ODEProblem(f,u0,tspan)
    sol = solve(prob, Rodas4())
    plot(sol)
end