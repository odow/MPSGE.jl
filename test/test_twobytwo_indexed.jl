@testset "TWOBYTWO (indexed version)" begin
    m = Model()
    goods = [:x, :y]
    factors = [:l, :k]
    consumers = [:ra]
    factor = DenseAxisArray(Float64[50 50; 20 30], goods, factors)
    supply = DenseAxisArray(Float64[100, 50], goods)
    endow = add!(m, Parameter(:endow, indices=(factors,), value=1.0)) 
    Y = add!(m, Sector(:Y, indices=(goods,)))
    U = add!(m, Sector(:U))
    PC = add!(m, Commodity(:PC, indices=(goods,)))
    PU = add!(m, Commodity(:PU))
    PF = add!(m, Commodity(:PF, indices=(factors,)))
    C = add!(m, Consumer(:C, indices=(consumers,), benchmark=150.))

    for i in goods
        @production(m, Y[i], 0, 1, [Output(PC[i], supply[i])], [Input(PF[:l], factor[i,:l]), Input(PF[:k], factor[i,:k])])
    end
    @production(m, U, 0, 1, [Output(PU, 150)], [Input(PC[:x], 100), Input(PC[:y], 50)])
    @demand(m, C[:ra], [Demand(PU, 150)], [Endowment(PF[:l], :(70 * $(endow[:l]))), Endowment(PF[:k], :(80. * $(endow[:k])))])

    solve!(m, cumulative_iteration_limit=0)
    gams_results = XLSX.readxlsx("MPSGEresults.xlsx")
    a_table = gams_results["TwoxTwoAlg"][:]
    two_by_two_Alg = DenseAxisArray(a_table[2:end,2:end],a_table[2:end,1],a_table[1,2:end])

    @test MPSGE.Complementarity.result_value(m._jump_model[:Y][:x]) ≈ two_by_two_Alg["Y.L","benchmark"] # 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:Y][:y]) ≈ two_by_two_Alg["X.L","benchmark"] # 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:U]) ≈ two_by_two_Alg["U.L","benchmark"] # 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:C][:ra]) ≈ two_by_two_Alg["RA.L","benchmark"] # 150.
    @test MPSGE.Complementarity.result_value(m._jump_model[:PC][:x]) ≈ two_by_two_Alg["PX.L","benchmark"] # 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:PC][:y]) ≈ two_by_two_Alg["PY.L","benchmark"] # 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:PU]) ≈ two_by_two_Alg["PU.L","benchmark"] # 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:l]) ≈ two_by_two_Alg["PL.L","benchmark"] # 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:k]) ≈ two_by_two_Alg["PK.L","benchmark"] # 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†Y[x]")]) ≈ two_by_two_Alg["LX.L","benchmark"] # 50.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†Y[y]")]) ≈ two_by_two_Alg["LY.L","benchmark"] # 20.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†Y[x]")]) ≈ two_by_two_Alg["KX.L","benchmark"] # 50.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†Y[y]")]) ≈ two_by_two_Alg["KY.L","benchmark"] # 30.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PC[x]†U")]) ≈ two_by_two_Alg["DX.L","benchmark"] # 100.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PC[y]†U")]) ≈ two_by_two_Alg["DY.L","benchmark"] # 50.

    set_fixed!(PC[:x], true)
    set_value(endow[:l], get_value(endow[:l]).*1.1)
    set_value(C[:ra], (get_value(endow[:k]) * 80. + get_value(endow[:l]) * 70.))
    set_fixed!(C[:ra], true)
    solve!(m)

    @test MPSGE.Complementarity.result_value(m._jump_model[:Y][:x]) ≈ two_by_two_Alg["X.L","RA=157"] # 1.04986567
    @test MPSGE.Complementarity.result_value(m._jump_model[:Y][:y]) ≈ two_by_two_Alg["Y.L","RA=157"] # 1.03676649
    @test MPSGE.Complementarity.result_value(m._jump_model[:U]) ≈ two_by_two_Alg["U.L","RA=157"] # 1.04335615
    @test MPSGE.Complementarity.result_value(m._jump_model[:C][:ra]) ≈ two_by_two_Alg["RA.L","RA=157"] # 157
    @test MPSGE.Complementarity.result_value(m._jump_model[:PC][:x]) ≈ two_by_two_Alg["PX.L","RA=157"] # 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:PC][:y]) ≈ two_by_two_Alg["PY.L","RA=157"] # 1.00954909
    @test MPSGE.Complementarity.result_value(m._jump_model[:PU]) ≈ two_by_two_Alg["PU.L","RA=157"] # 1.00317295
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:l]) ≈ two_by_two_Alg["PL.L","RA=157"] # 0.95359243
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:k]) ≈ two_by_two_Alg["PK.L","RA=157"] # 1.04866605
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†Y[x]")]) ≈ two_by_two_Alg["LX.L","RA=157"] # 
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†Y[y]")]) ≈ two_by_two_Alg["LY.L","RA=157"] # 
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†Y[x]")]) ≈ two_by_two_Alg["KX.L","RA=157"] # 
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†Y[y]")]) ≈ two_by_two_Alg["KY.L","RA=157"] # 
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PC[x]†U")]) ≈ two_by_two_Alg["DX.L","RA=157"] # 
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PC[y]†U")]) ≈ two_by_two_Alg["DY.L","RA=157"] # 

    set_fixed!(C[:ra], false)
    set_fixed!(PC[:x], true)

    solve!(m)
    @test MPSGE.Complementarity.result_value(m._jump_model[:Y][:x]) ≈ two_by_two_Alg["X.L","PX=1"] # 1.04880885
    @test MPSGE.Complementarity.result_value(m._jump_model[:Y][:y]) ≈ two_by_two_Alg["Y.L","PX=1"] # 1.03886012
    @test MPSGE.Complementarity.result_value(m._jump_model[:U]) ≈ two_by_two_Alg["U.L","PX=1"] # 1.04548206
    @test MPSGE.Complementarity.result_value(m._jump_model[:C][:ra]) ≈ two_by_two_Alg["RA.L","PX=1"] # 157.321327225523
    @test MPSGE.Complementarity.result_value(m._jump_model[:PC][:x]) ≈ two_by_two_Alg["PX.L","PX=1"] # 1.0000000000
    @test MPSGE.Complementarity.result_value(m._jump_model[:PC][:y]) ≈ two_by_two_Alg["PY.L","PX=1"] # 1.00957658
    @test MPSGE.Complementarity.result_value(m._jump_model[:PU]) ≈ two_by_two_Alg["PU.L","PX=1"] # 1.00318206
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:l]) ≈ two_by_two_Alg["PL.L","PX=1"] # 0.95346259
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:k]) ≈ two_by_two_Alg["PK.L","PX=1"] # 1.04880885
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†Y[x]")]) ≈ two_by_two_Alg["LX.L","PX=1"] # 52.4404424085075
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†Y[y]")]) ≈ two_by_two_Alg["LY.L","PX=1"] # 21.1770570584356
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†Y[x]")]) ≈ two_by_two_Alg["KX.L","PX=1"] # 47.6731294622795
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†Y[y]")]) ≈ two_by_two_Alg["KY.L","PX=1"] # 28.877805079685
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PC[x]†U")]) ≈ two_by_two_Alg["DX.L","PX=1"] # 100.318205802571
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PC[y]†U")]) ≈ two_by_two_Alg["DY.L","PX=1"] # 49.6833066029729

    set_fixed!(PC[:x], false)
    set_fixed!(PF[:l], true)
    solve!(m)
            
    @test MPSGE.Complementarity.result_value(m._jump_model[:Y][:x]) ≈ two_by_two_Alg["X.L","PL=1"] # 1.04880885
    @test MPSGE.Complementarity.result_value(m._jump_model[:Y][:y]) ≈ two_by_two_Alg["Y.L","PL=1"] # 1.03886012
    @test MPSGE.Complementarity.result_value(m._jump_model[:U]) ≈ two_by_two_Alg["U.L","PL=1"] # 1.04548206
    @test MPSGE.Complementarity.result_value(m._jump_model[:C][:ra]) ≈ two_by_two_Alg["RA.L","PL=1"] # 165
    @test MPSGE.Complementarity.result_value(m._jump_model[:PC][:x]) ≈ two_by_two_Alg["PX.L","PL=1"] # 1.04880885
    @test MPSGE.Complementarity.result_value(m._jump_model[:PC][:y]) ≈ two_by_two_Alg["PY.L","PL=1"] # 1.05885285
    @test MPSGE.Complementarity.result_value(m._jump_model[:PU]) ≈ two_by_two_Alg["PU.L","PL=1"] # 1.05214622
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:l]) ≈ two_by_two_Alg["PL.L","PL=1"] # 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:k]) ≈ two_by_two_Alg["PK.L","PL=1"] # 1.1
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†Y[x]")]) ≈ two_by_two_Alg["LX.L","PL=1"] # 52.44044241
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†Y[y]")]) ≈ two_by_two_Alg["LY.L","PL=1"] # 21.17705706
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†Y[x]")]) ≈ two_by_two_Alg["KX.L","PL=1"] # 47.67312946
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†Y[y]")]) ≈ two_by_two_Alg["KY.L","PL=1"] # 28.87780508
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PC[x]†U")]) ≈ two_by_two_Alg["DX.L","PL=1"] # 100.3182058
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PC[y]†U")]) ≈ two_by_two_Alg["DY.L","PL=1"] # 49.6833066

end