# ------------------------------------------------
# Test: ProblemTemplates
#
# 1. test UnitarySmoothPulseProblem
# 2. test UnitaryMinimumTimeProblem
# 3. test UnitaryRobustnessProblem
# ------------------------------------------------


@testset "Problem Templates" begin

    H_drift = GATES[:Z]
    H_drives = [GATES[:X], GATES[:Y]]
    U_goal = GATES[:H]
    T = 50
    Δt = 0.2

    # --------------------------------------------
    # 1. test UnitarySmoothPulseProblem
    # --------------------------------------------

    prob = UnitarySmoothPulseProblem(H_drift, H_drives, U_goal, T, Δt)

    solve!(prob; max_iter=100)

    @test unitary_fidelity(prob) > 0.99

    # --------------------------------------------
    # 2. test UnitaryMinimumTimeProblem
    # --------------------------------------------

    final_fidelity = 0.99

    mintime_prob = UnitaryMinimumTimeProblem(prob; final_fidelity=final_fidelity)

    solve!(mintime_prob; max_iter=100)

    @test unitary_fidelity(mintime_prob) > final_fidelity

    @test times(mintime_prob.trajectory)[end] < times(prob.trajectory)[end]

end



@testset "Robust and Subspace Templates" begin
    # --------------------------------------------
    # Initialize with UnitarySmoothPulseProblem
    # --------------------------------------------
    H_drift = zeros(2, 2)
    H_drives = [GATES[:X], GATES[:Y]]
    U_goal = GATES[:X]
    T = 50
    Δt = .2

    probs = Dict()
    
    probs["qubit"] = UnitarySmoothPulseProblem(
        H_drift, H_drives, U_goal, T, Δt;
        verbose=false
    )
    
    solve!(probs["qubit"]; max_iter=100)
    
    @test unitary_fidelity(probs["qubit"]) > 0.99
    
    # --------------------------------------------
    # 1. test UnitarySmoothPulseProblem with subspace
    # --------------------------------------------
    H_error = GATES[:Z]
    H_drift = zeros(3, 3)
    H_drives = [create(3) + annihilate(3), im * (create(3) - annihilate(3))]
    U_goal = [0 1 0; 1 0 0; 0 0 0]
    T = probs["qubit"].trajectory.T
    Δt = probs["qubit"].trajectory[:Δt][1]
    a_guess = probs["qubit"].trajectory[:a]
    
    subspace = subspace_indices([3])
    probs["transmon"] = UnitarySmoothPulseProblem(
        H_drift, H_drives, U_goal, T, Δt;
        a_guess=a_guess, subspace=subspace, geodesic=false, verbose=false
    )
    solve!(probs["transmon"]; max_iter=100)
    
    # Subspace gate success
    @test unitary_fidelity(probs["transmon"]; subspace=subspace) > 0.99


    # --------------------------------------------
    # 3. test UnitaryRobustnessProblem from previous problem
    # --------------------------------------------
    probs["robust"] = UnitaryRobustnessProblem(
        H_error, probs["transmon"];
        final_fidelity=0.99, subspace=subspace, verbose=false    
    )
    solve!(probs["robust"]; max_iter=100)
    
    EvalLoss(problem, Loss) = Loss(vec(problem.trajectory.data), problem.trajectory)
    Loss = InfidelityRobustnessObjective(H_error, probs["transmon"].trajectory).L

    # Robustness improvement over default
    @test EvalLoss(probs["robust"], Loss) < EvalLoss(probs["transmon"], Loss)
    
    # Fidelity constraint approximately satisfied
    @test isapprox(unitary_fidelity(probs["robust"]; subspace=subspace), 0.99, atol=0.025)
    
    # --------------------------------------------
    # 4. test UnitaryRobustnessProblem from default struct
    # --------------------------------------------
    params = deepcopy(probs["transmon"].params)
    trajectory = copy(probs["transmon"].trajectory)
    system = probs["transmon"].system
    objective = QuadraticRegularizer(:dda, trajectory, 1e-4)
    integrators = probs["transmon"].integrators
    constraints = AbstractConstraint[]
    
    probs["unconstrained"] = UnitaryRobustnessProblem(
        H_error, trajectory, system, objective, integrators, constraints;
        final_fidelity=0.99, subspace=subspace, verbose=false
    )
    solve!(probs["unconstrained"]; max_iter=100)
    
    # Additonal robustness improvement after relaxed objective
    @test EvalLoss(probs["unconstrained"], Loss) < EvalLoss(probs["transmon"], Loss)
    
    # Fidelity constraint approximately satisfied
    @test isapprox(unitary_fidelity(probs["unconstrained"]; subspace=subspace), 0.99, atol=0.025)


end
