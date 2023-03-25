"""
    Testing dynamics derivatives
"""

@testset "Dynamics" begin
    # initializing test trajectory
    T = 10
    H_drift = GATES[:Z]
    H_drives = [GATES[:X], GATES[:Y]]

    system = QuantumSystem(H_drift, H_drives)

    @testset "State Dynamics" begin

        P = FourthOrderPade(system)

        Z = NamedTrajectory(
            (
                ψ̃ = randn(4, T),
                u = randn(2, T),
                du = randn(2, T)
            ),
            controls=:du,
            dt=0.1,
            goal=(ψ̃ = [1, 0, 0, 0],)
        )

        function f(zₜ, zₜ₊₁)
            ψ̃ₜ₊₁ = zₜ₊₁[Z.components.ψ̃]
            ψ̃ₜ = zₜ[Z.components.ψ̃]
            uₜ = zₜ[Z.components.u]
            uₜ₊₁ = zₜ₊₁[Z.components.u]
            duₜ = zₜ[Z.components.du]
            δψ̃ = P(ψ̃ₜ₊₁, ψ̃ₜ, uₜ, Z.dt)
            δu = uₜ₊₁ - uₜ - duₜ * Z.dt
            return vcat(δψ̃, δu)
        end

        dynamics = QuantumDynamics(f, Z)

        # test dynamics jacobian
        shape = (Z.dims.states * (Z.T - 1), Z.dim * Z.T)
        @test ForwardDiff.jacobian(dynamics.F, Z.datavec) ≈
            dense(dynamics.∂F(Z.datavec), dynamics.∂F_structure, shape)

        # test dynamics hessian of the lagrangian
        shape = (Z.dim * Z.T, Z.dim * Z.T)
        μ = rand(Z.dims.states * (Z.T - 1))
        @test ForwardDiff.hessian(Z⃗ -> μ' * dynamics.F(Z⃗), Z.datavec) ≈
            dense(dynamics.μ∂²F(Z.datavec, μ), dynamics.μ∂²F_structure, shape)


    end

end