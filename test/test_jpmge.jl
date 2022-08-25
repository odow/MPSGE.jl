@testitem "JPMGE (Joint Production Intermediate Demand)" begin
    using XLSX, MPSGE.JuMP.Containers
    
#A replication of the JPMGE from https://www.gams.com/34/docs/UG_MPSGE_Intro.html#UG_MPSGE_Intro_Appendix_jpmge
    m = Model()
    goods = [:g1, :g2]
    factors = [:l, :k]
    sectors = [:s1, :s2]
    make0 = DenseAxisArray(Float64[6 2; 2 10], goods, sectors)
    use0 = DenseAxisArray(Float64[4 2; 2 6], goods, sectors)
    fd0 = DenseAxisArray(Float64[1 3; 1 1], factors, sectors)
    c0 = DenseAxisArray(Float64[2, 4], goods)
    e0 = DenseAxisArray(Float64[sum(fd0[f,:]) for f in factors], factors)
    endow = add!(m, Parameter(:endow, indices=(factors,), value=1.0)) 
    X = add!(m, Sector(:X, indices=(sectors,)))
    P = add!(m, Commodity(:P, indices=(goods,)))
    PF = add!(m, Commodity(:PF, indices=(factors,)))
    Y = add!(m, Consumer(:Y, benchmark=sum(fd0)))#example 4 has sum e0
    for j in sectors
        @production(m, X[j], 1., 1., [Output(P[i], make0[i,j]) for i in goods], [[Input(P[i], use0[i,j]) for i in goods]; [Input(PF[f], fd0[f,j]) for f in factors]])
    end

    @demand(m, Y, 1., [Demand(P[i], c0[i]) for i in goods], [Endowment(PF[:k], :($(endow[:k]) * $(e0[:k]))), Endowment(PF[:l], :($(endow[:l]) * $(e0[:l])))])

    avm = algebraic_version(m)
    @test typeof(avm) == MPSGE.AlgebraicWrapper

    solve!(m)

    gams_results = XLSX.readxlsx(joinpath(@__DIR__, "MPSGEresults.xlsx"))
    a_table = gams_results["JPMGE"][:]  # Generated from JPMGE_MPSGE
    two_by_two_jpmge = DenseAxisArray(a_table[2:end,3:end],string.(a_table[2:end,1],".",a_table[2:end,2]),a_table[1,3:end])

    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s1]) ≈ two_by_two_jpmge["X.s1","benchmark"] # 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s2]) ≈ two_by_two_jpmge["X.s2","benchmark"] # 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g1]) ≈ two_by_two_jpmge["P.g1","benchmark"] # 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g2]) ≈ two_by_two_jpmge["P.g2","benchmark"] # 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:l]) ≈ two_by_two_jpmge["PF.labor","benchmark"] # 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:k]) ≈ two_by_two_jpmge["PF.capital","benchmark"] # 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:Y]) ≈ two_by_two_jpmge["Y._","benchmark"] # 6.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]ρY")]) ≈ two_by_two_jpmge["PY.g1","benchmark"] # 2.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]ρY")]) ≈ two_by_two_jpmge["PY.g2","benchmark"] # 4.
#Implicit Variables
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s1]")]) ≈ two_by_two_jpmge["g1.s1","benchmark"] # 6.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s1]")]) ≈ two_by_two_jpmge["g2.s1","benchmark"] # 2.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s2]")]) ≈ two_by_two_jpmge["g1.s2","benchmark"] # 2.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s2]")]) ≈ two_by_two_jpmge["g2.s2","benchmark"] # 10.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s1]")]) ≈ two_by_two_jpmge["labor.s1","benchmark"] # 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s1]")]) ≈ two_by_two_jpmge["capital.s1","benchmark"] # 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s2]")]) ≈ two_by_two_jpmge["labor.s2","benchmark"] # 3.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s2]")]) ≈ two_by_two_jpmge["capital.s2","benchmark"] # 1.
#Separate column in GAMS results bc of display limitation
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s1]")]) ≈ two_by_two_jpmge["g1.s1","D benchmark"] # 4.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s2]")]) ≈ two_by_two_jpmge["g1.s2","D benchmark"] # 2.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s1]")]) ≈ two_by_two_jpmge["g2.s1","D benchmark"] # 2.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s2]")]) ≈ two_by_two_jpmge["g2.s2","D benchmark"] # 6.
    
    
    #Counter-factual 1, labour supply increased by 10%
    set_value(endow[:l], 1.1*get_value(endow[:l]))
    set_fixed!(Y, true)

    solve!(m)
    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s1]) ≈ two_by_two_jpmge["X.s1","Y=6.4"] #  0.996925617428788
    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s2]) ≈ two_by_two_jpmge["X.s2","Y=6.4"] #  1.09975731472318
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g1]) ≈ two_by_two_jpmge["P.g1","Y=6.4"] #  1.01306317269819
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g2]) ≈ two_by_two_jpmge["P.g2","Y=6.4"] #  0.994678919645562
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:l]) ≈ two_by_two_jpmge["PF.labor","Y=6.4"] #  0.976659316086759
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:k]) ≈ two_by_two_jpmge["PF.capital","Y=6.4"] #  1.05134950457745
    @test MPSGE.Complementarity.result_value(m._jump_model[:Y]) ≈ two_by_two_jpmge["Y._","Y=6.4"] #  6.4
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]ρY")]) ≈ two_by_two_jpmge["PY.g1","Y=6.4"] #  2.1058245831318 , previous was 2.1058245831306
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]ρY")]) ≈ two_by_two_jpmge["PY.g2","Y=6.4"] #  4.28949139505945 , previous was 4.28949135539776

    # Implicit variables don't match
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s1]")]) ≈ two_by_two_jpmge["g1.s1","Y=6.4"]  #  6.00862728276079
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s1]")]) ≈ two_by_two_jpmge["g2.s1","D Y=6.4"] #  2.23323523212149
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s2]")]) ≈ two_by_two_jpmge["g1.s2","Y=6.4"] #  1.966529187662
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s2]")]) ≈ two_by_two_jpmge["g2.s2","Y=6.4"] #  10.9635414052447
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s1]")]) ≈ two_by_two_jpmge["labor.s1","Y=6.4"] #  1.02942551383858
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s1]")]) ≈ two_by_two_jpmge["capital.s1","Y=6.4"] #  3.37057448620877
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s2]")]) ≈ two_by_two_jpmge["labor.s2","Y=6.4"] #  0.956292854022821
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s2]")]) ≈ two_by_two_jpmge["capital.s2","Y=6.4"] #  1.04370714597052
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s1]")]) ≈ two_by_two_jpmge["g1.s1","Y=6.4"] #  3.96973474272125
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s2]")]) ≈ two_by_two_jpmge["g1.s2","Y=6.4"] #  2.16630318900549
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s1]")]) ≈ two_by_two_jpmge["g2.s1","D Y=6.4"] #  2.02155288194126
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s2]")]) ≈ two_by_two_jpmge["g2.s2","D Y=6.4"] #  6.61902631593552

    # Match from Algebraic version
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s1]")]) ≈ 6.0271570795595 atol=1.0e-7# two_by_two_jpmge["P.g1","Y=6.4"] implicit don't match
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s1]")]) ≈ 1.97259368637181 atol=1.0e-7 # two_by_two_jpmge["P.g1","Y=6.4"] implicit don't match
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s2]")]) ≈ 2.03066186698742 atol=1.0e-7 # two_by_two_jpmge["P.g1","Y=6.4"] implicit don't match
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s2]")]) ≈ 9.96905522562002 atol=1.0e-7 ##note - digits after 9.969 added from MPSGE.jl results bc GAMS not showing  
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s1]")]) ≈ 3.98197684247759 atol=1.0e-7 # two_by_two_jpmge["P.g1","Y=6.4"] implicit don't match
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s1]")]) ≈ 2.02778707866119 atol=1.0e-7 # two_by_two_jpmge["P.g1","Y=6.4"] implicit don't match
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s1]")]) ≈ 1.03260012599366 atol=1.0e-7 # two_by_two_jpmge["P.g1","Y=6.4"] implicit don't match
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s1]")]) ≈ 0.959241925360056 atol=1.0e-7 # two_by_two_jpmge["P.g1","Y=6.4"] implicit don't match
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s2]")]) ≈ 1.96980110341978 atol=1.0e-7 # two_by_two_jpmge["P.g1","Y=6.4"] implicit don't match
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s2]")]) ≈ 6.018624497730061 atol=1.0e-7 ##note - digits after 6.0186 added from MPSGE.jl results bc GAMS not showing  
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s2]")]) ≈ 3.06483480444652 atol=1.0e-7 # two_by_two_jpmge["P.g1","Y=6.4"] implicit don't match
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s2]")]) ≈ 0.94903406 atol=1.0e-7 # two_by_two_jpmge["P.g1","Y=6.4"] implicit don't match

    # Counter-factual 2, use Price of good 1 as the numeraire
    set_fixed!(Y,false)
    set_fixed!(P[:g1], true)
    solve!(m)
    
    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s1]) ≈ two_by_two_jpmge["X.s1","P(\"g1\")=1"] #  0.996925632214485, previous was 0.996925617439043
    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s2]) ≈ two_by_two_jpmge["X.s2","P(\"g1\")=1"] #  1.09975731240985, previous was 1.09975731474277
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g1]) ≈ two_by_two_jpmge["P.g1","P(\"g1\")=1"] #  1
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g2]) ≈ two_by_two_jpmge["P.g2","P(\"g1\")=1"] #  0.98185279887846, previous was 0.981852806861767
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:l]) ≈ two_by_two_jpmge["PF.labor","P(\"g1\")=1"] atol=0.0000001#  0.964065543125743, previous was 0.964065561173485
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:k]) ≈ two_by_two_jpmge["PF.capital","P(\"g1\")=1"] #  1.03779263434603, previous was 1.0377926401152
    @test MPSGE.Complementarity.result_value(m._jump_model[:Y]) ≈ two_by_two_jpmge["Y._","P(\"g1\")=1"] #  6.31747365844533
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]ρY")]) ≈ two_by_two_jpmge["PY.g1","P(\"g1\")=1"] #  2.10582455281511
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]ρY")]) ≈ two_by_two_jpmge["PY.g2","P(\"g1\")=1"] #  4.28949136819802
    @test MPSGE.Complementarity.result_value(m._jump_model[:Y]) ≈ two_by_two_jpmge["Y._","P(\"g1\")=1"] # 6.31747374939373 # not quite…6.31747363
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]ρY")]) ≈ two_by_two_jpmge["PY.g1","P(\"g1\")=1"] # 2.10582458313124 # not quite…2.10582454
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]ρY")]) ≈ two_by_two_jpmge["PY.g2","P(\"g1\")=1"] # 4.28949139508602 # not quite…4.28949136
    
    # Implicit variables don't match
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s1]")]) ≈ two_by_two_jpmge["g1.s1","P(\"g1\")=1"] #  6.00862738376312
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s1]")]) ≈ two_by_two_jpmge["g2.s1","P(\"g1\")=1"] #  2.23323524246878
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s2]")]) ≈ two_by_two_jpmge["g1.s2","P(\"g1\")=1"] #  1.96652920472186
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s2]")]) ≈ two_by_two_jpmge["g2.s2","P(\"g1\")=1"] #  10.96354136686
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s1]")]) ≈ two_by_two_jpmge["labor.s1","P(\"g1\")=1"] #  1.02942554315807
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s1]")]) ≈ two_by_two_jpmge["capital.s1","P(\"g1\")=1"] #  3.37057451116578
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s2]")]) ≈ two_by_two_jpmge["labor.s2","P(\"g1\")=1"] #  0.956292868659245
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s2]")]) ≈ two_by_two_jpmge["capital.s2","P(\"g1\")=1"] #  1.0437071399466
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s1]")]) ≈ two_by_two_jpmge["g1.s1","D P(\"g1\")=1"] #  3.9697347814888
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s2]")]) ≈ two_by_two_jpmge["g1.s2","D P(\"g1\")=1"] #  2.16630316450188
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s1]")]) ≈ two_by_two_jpmge["g2.s1","D P(\"g1\")=1"] #  2.0215529181275
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s2]")]) ≈ two_by_two_jpmge["g2.s2","D P(\"g1\")=1"] #  6.6190262949081
    # Match from Algebraic version
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s1]")]) ≈ 6.02715706941587#note - digits after 6.0272 added from MPSGE.jl results bc GAMS not showing
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s1]")]) ≈ 1.97259369533833#note - digits after 1.9726 added from MPSGE.jl results bc GAMS not showing
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s2]")]) ≈ 2.03066185804686#note - digits after 2.0307 added from MPSGE.jl results bc GAMS not showing
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s2]")]) ≈ 9.96905522562263#note - digits after 9.9691 added from MPSGE.jl results bc GAMS not showing
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s1]")]) ≈ 3.98197686300985#note - digits after 3.982 added from MPSGE.jl results bc GAMS not showing
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s1]")]) ≈ 2.02778707519236#note - digits after 2.0278 added from MPSGE.jl results bc GAMS not showing
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s1]")]) ≈ 1.0326001216173 # not quite…1.03260013
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s1]")]) ≈ 0.959241930675824#note - digits after 0.95924193 added from MPSGE.jl results bc GAMS not showing
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s2]")]) ≈ 1.96980111885957#note - digits after 1.9698 added from MPSGE.jl results bc GAMS not showing
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s2]")]) ≈ 6.01862449776752#note - digits after 6.0186 added from MPSGE.jl results bc GAMS not showing
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s2]")]) ≈ 3.06483479672782#note - digits after 3.0648348 added from MPSGE.jl results bc GAMS not showing
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s2]")]) ≈ 0.949034056851536#note - digits after 0.94903405 added from MPSGE.jl results bc GAMS not showing
                 
    # Counter-factual 3, use price of labour (wages) as the numeraire
    set_fixed!(P[:g1], false)
    set_fixed!(PF[:l], true)
    solve!(m)

    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s1]) ≈ two_by_two_jpmge["X.s1","PF(\"labor\")=1"] #  0.996925617427381 , previous was # 0.996925617406936
    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s2]) ≈ two_by_two_jpmge["X.s2","PF(\"labor\")=1"] #  1.09975731471612 , previous was 1.09975731471521
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g1]) ≈ two_by_two_jpmge["P.g1","PF(\"labor\")=1"] #  1.03727385384161 , previous was 1.03727385383628
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g2]) ≈ two_by_two_jpmge["P.g2","PF(\"labor\")=1"] #  1.01845024488663 , previous was 1.01845024488441
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:l]) ≈ two_by_two_jpmge["PF.labor","PF(\"labor\")=1"] #  1
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:k]) ≈ two_by_two_jpmge["PF.capital","PF(\"labor\")=1"] #  1.07647517127483 , previous was 1.07647517126301
    @test MPSGE.Complementarity.result_value(m._jump_model[:Y]) ≈ two_by_two_jpmge["Y._","PF(\"labor\")=1"] #  6.55295034254966 ,previous  was 6.55295034252603 # not quite…6.55295028
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]ρY")]) ≈ two_by_two_jpmge["PY.g1","PF(\"labor\")=1"] #  2.10582458312251 , previous was 2.10582458311357# not quite…2.10582449
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]ρY")]) ≈ two_by_two_jpmge["PY.g2","PF(\"labor\")=1"] #  4.2894913950225 , previous was 4.28949139501026# not quite…4.28949135
 
    # Implicit variables now don't match   
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s1]")]) ≈ two_by_two_jpmge["g1.s1","D PF(\"labor\")=1"] #  3.96973474272271
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s2]")]) ≈ two_by_two_jpmge["g1.s2","D PF(\"labor\")=1"] #  2.16630318900094
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s1]")]) ≈ two_by_two_jpmge["g2.s1","D PF(\"labor\")=1"] #  2.0215528819335
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s2]")]) ≈ two_by_two_jpmge["g2.s2","D PF(\"labor\")=1"] #  6.61902631589382
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s1]")]) ≈ two_by_two_jpmge["g1.s1","PF(\"labor\")=1"] #  6.00862728274617
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s1]")]) ≈ two_by_two_jpmge["g2.s1","PF(\"labor\")=1"] #  2.23323523209938
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s2]")]) ≈ two_by_two_jpmge["g1.s2","PF(\"labor\")=1"] #  1.96652918766548
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s2]")]) ≈ two_by_two_jpmge["g2.s2","PF(\"labor\")=1"] #  10.9635414051822
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s1]")]) ≈ two_by_two_jpmge["labor.s1","PF(\"labor\")=1"] #  1.02942551382823
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s1]")]) ≈ two_by_two_jpmge["capital.s1","PF(\"labor\")=1"] #  3.37057448616656
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s2]")]) ≈ two_by_two_jpmge["labor.s2","PF(\"labor\")=1"] #  0.956292854027573
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s2]")]) ≈ two_by_two_jpmge["capital.s2","PF(\"labor\")=1"] #  1.04370714597313
   # Match from Algebraic GAMS version
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s1]")]) ≈ 6.02715706940364  #note - digits after 6.0272 added from MPSGE.jl results bc GAMS not showing
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s1]")]) ≈ 1.97259369534545  #note - digits after 1.9726 added from MPSGE.jl results bc GAMS not showing
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s2]")]) ≈ 2.03066185804338  #note - digits after 2.0307 added from MPSGE.jl results bc GAMS not showing
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s2]")]) ≈ 9.96905522562005#note - digits after 9.9691 added from MPSGE.jl results bc GAMS not showing
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s1]")]) ≈ 3.98197686299145 #note - digits after 3.982 added from MPSGE.jl results bc GAMS not showing
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s1]")]) ≈ 2.02778707517633 #note - digits after 2.0278 added from MPSGE.jl results bc GAMS not showing
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s2]")]) ≈ 1.96980111885675 #note - digits after 1.9698 added from MPSGE.jl results bc GAMS not showing
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s2]")]) ≈ 6.01862449771423 #note - digits after 6.0186 added from MPSGE.jl results bc GAMS not showing
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s1]")]) ≈ 1.03260012164254# not quite…1.03260003
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s1]")]) ≈ 0.959241930707878# not quite…0.9592419
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s2]")]) ≈ 3.06483479678299# not quite…3.06483456
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s2]")]) ≈ 0.949034056889784# not quite…0.94903402

#A replication of the JPMGE from https://www.gams.com/34/docs/UG_MPSGE_Intro.html#UG_MPSGE_Intro_Appendix_jpmge
# Re-running the model and tests as checks on different Demand elasticities - here with Demand elasticity = 0 (Leontief)
    m = Model()
# All indexes and data as above
    endow = add!(m, Parameter(:endow, indices=(factors,), value=1.0)) 
    X = add!(m, Sector(:X, indices=(sectors,)))
    P = add!(m, Commodity(:P, indices=(goods,)))
    PF = add!(m, Commodity(:PF, indices=(factors,)))
    Y = add!(m, Consumer(:Y, benchmark=sum(fd0)))#example 4 has sum e0
    for j in sectors
        @production(m, X[j], 1, 1, [Output(P[i], make0[i,j]) for i in goods], [[Input(P[i], use0[i,j]) for i in goods]; [Input(PF[f], fd0[f,j]) for f in factors]])
    end

    @demand(m, Y, 0., [Demand(P[i], c0[i]) for i in goods], [Endowment(PF[:k], :($(endow[:k]) * $(e0[:k]))), Endowment(PF[:l], :($(endow[:l]) * $(e0[:l])))])

    avm = algebraic_version(m)
    @test typeof(avm) == MPSGE.AlgebraicWrapper

    solve!(m)

    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s1]) ≈ 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s2]) ≈ 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g1]) ≈ 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g2]) ≈ 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:l]) ≈ 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:k]) ≈ 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:Y]) ≈ 6.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s1]")]) ≈ 6.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s1]")]) ≈ 2.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s2]")]) ≈ 2.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s2]")]) ≈ 10.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s1]")]) ≈ 4.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s1]")]) ≈ 2.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s1]")]) ≈ 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s1]")]) ≈ 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s2]")]) ≈ 2.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s2]")]) ≈ 6.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s2]")]) ≈ 3.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s2]")]) ≈ 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]ρY")]) ≈ 2.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]ρY")]) ≈ 4.

    #Counter-factual 1, labour supply increased by 10%
    set_value(endow[:l], 1.1*get_value(endow[:l]))
    set_fixed!(Y, true)

    solve!(m)
    
    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s1]) ≈ two_by_two_jpmge["X.s1","D_elas=0,Y=6.4"] #  1.00695565465906
    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s2]) ≈ two_by_two_jpmge["X.s2","D_elas=0,Y=6.4"] #  1.09465569946758
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g1]) ≈ two_by_two_jpmge["P.g1","D_elas=0,Y=6.4"] #  1.01368184594903
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g2]) ≈ two_by_two_jpmge["P.g2","D_elas=0,Y=6.4"] #  0.994372399169794
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:l]) ≈ two_by_two_jpmge["PF.labor","D_elas=0,Y=6.4"] #  0.975465157228405
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:k]) ≈ two_by_two_jpmge["PF.capital","D_elas=0,Y=6.4"] #  1.05397665409716
    @test MPSGE.Complementarity.result_value(m._jump_model[:Y]) ≈ two_by_two_jpmge["Y._","D_elas=0,Y=6.4"] #  6.4
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]ρY")]) ≈ two_by_two_jpmge["PY.g1","D_elas=0,Y=6.4"] #  2.13160911430574
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]ρY")]) ≈ two_by_two_jpmge["PY.g2","D_elas=0,Y=6.4"] #  4.26321822861147

    # Implicit variables don't match
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s1]")]) ≈ two_by_two_jpmge["g1.s1","D_elas=0,Y=6.4"] atol=0.000001 #  6.07043510191851
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s1]")]) ≈ two_by_two_jpmge["g2.s1","D_elas=0,Y=6.4"] #  2.22456726455408
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s2]")]) ≈ two_by_two_jpmge["g1.s2","D_elas=0,Y=6.4"] #  1.9849334846109
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s2]")]) ≈ two_by_two_jpmge["g2.s2","D_elas=0,Y=6.4"] #  10.9109593745278
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s1]")]) ≈ two_by_two_jpmge["labor.s1","D_elas=0,Y=6.4"] #  1.04145864038388
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s1]")]) ≈ two_by_two_jpmge["capital.s1","D_elas=0,Y=6.4"] #  3.35854135961615
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s2]")]) ≈ two_by_two_jpmge["labor.s2","D_elas=0,Y=6.4"] #  0.963879619572001
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s2]")]) ≈ two_by_two_jpmge["capital.s2","D_elas=0,Y=6.4"] #  1.03612038042798
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s1]")]) ≈ two_by_two_jpmge["g1.s1","D D_elas=0,Y=6.4"] #  4.00877896925472
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s2]")]) ≈ two_by_two_jpmge["g1.s2","D D_elas=0,Y=6.4"] #  2.15461428291233
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s1]")]) ≈ two_by_two_jpmge["g2.s1","D D_elas=0,Y=6.4"] #  2.04331217808766
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s2]")]) ≈ two_by_two_jpmge["g2.s2","D D_elas=0,Y=6.4"] #  6.58936245244002
  
    # Counter-factual 2, use Price of good 1 as the numeraire
    set_fixed!(Y,false)
    set_fixed!(P[:g1], true)
    solve!(m)
    
    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s1]) ≈ two_by_two_jpmge["X.s1","D_elas=0,P(\"g1\")=1"] atol=0.0000001#  1.00695567662299
    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s2]) ≈ two_by_two_jpmge["X.s2","D_elas=0,P(\"g1\")=1"] #  1.09465569446489
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g1]) ≈ two_by_two_jpmge["P.g1","D_elas=0,P(\"g1\")=1"] #  1
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g2]) ≈ two_by_two_jpmge["P.g2","D_elas=0,P(\"g1\")=1"] #  0.980951166489968
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:l]) ≈ two_by_two_jpmge["PF.labor","D_elas=0,P(\"g1\")=1"] atol=0.0000001 #  0.96229910684127
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:k]) ≈ two_by_two_jpmge["PF.capital","D_elas=0,P(\"g1\")=1"] atol=0.0000001 #  1.0397509357684
    @test MPSGE.Complementarity.result_value(m._jump_model[:Y]) ≈ two_by_two_jpmge["Y._","D_elas=0,P(\"g1\")=1"] atol=0.000001 #  6.31361794163839
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]ρY")]) ≈ two_by_two_jpmge["PY.g1","D_elas=0,P(\"g1\")=1"] #  2.13160909167668
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]ρY")]) ≈ two_by_two_jpmge["PY.g2","D_elas=0,P(\"g1\")=1"] #  4.26321818335335
    @test MPSGE.Complementarity.result_value(m._jump_model[:Y]) ≈ two_by_two_jpmge["Y._","D_elas=0,P(\"g1\")=1"] atol = 0.000001#

    # Implicit variables don't match  
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s1]")]) ≈ two_by_two_jpmge["g1.s1","D_elas=0,P(\"g1\")=1"] #  6.07043524905978
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s1]")]) ≈ two_by_two_jpmge["g2.s1","D_elas=0,P(\"g1\")=1"] #  2.22456727279169
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s2]")]) ≈ two_by_two_jpmge["g1.s2","D_elas=0,P(\"g1\")=1"] #  1.984933512889
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s2]")]) ≈ two_by_two_jpmge["g2.s2","D_elas=0,P(\"g1\")=1"] #  10.9109593059021
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s1]")]) ≈ two_by_two_jpmge["labor.s1","D_elas=0,P(\"g1\")=1"] #  1.04145868051914
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s1]")]) ≈ two_by_two_jpmge["capital.s1","D_elas=0,P(\"g1\")=1"] #  3.35854138329698
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s2]")]) ≈ two_by_two_jpmge["labor.s2","D_elas=0,P(\"g1\")=1"] #  0.963879640401586
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s2]")]) ≈ two_by_two_jpmge["capital.s2","D_elas=0,P(\"g1\")=1"] #  1.03612037019476
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s1]")]) ≈ two_by_two_jpmge["g1.s1","D D_elas=0,P(\"g1\")=1"] #  4.00877903230264
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s2]")]) ≈ two_by_two_jpmge["g1.s2","D D_elas=0,P(\"g1\")=1"] #  2.15461424895742
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s1]")]) ≈ two_by_two_jpmge["g2.s1","D D_elas=0,P(\"g1\")=1"] #  2.04331223064183
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s2]")]) ≈ two_by_two_jpmge["g2.s2","D D_elas=0,P(\"g1\")=1"] #  6.58936241444223
               
    # Counter-factual 3, use price of labour (wages) as the numeraire
    set_fixed!(P[:g1], false)
    set_fixed!(PF[:l], true)
    solve!(m)

    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s1]) ≈ two_by_two_jpmge["X.s1","D_elas=0,PF(\"l\")=1"] #  1.00695565465863
    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s2]) ≈ two_by_two_jpmge["X.s2","D_elas=0,PF(\"l\")=1"] #  1.0946556994654
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g1]) ≈ two_by_two_jpmge["P.g1","D_elas=0,PF(\"l\")=1"] #  1.03917791264692
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g2]) ≈ two_by_two_jpmge["P.g2","D_elas=0,PF(\"l\")=1"] #  1.01938279578824
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:l]) ≈ two_by_two_jpmge["PF.labor","D_elas=0,PF(\"l\")=1"] #  1
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:k]) ≈ two_by_two_jpmge["PF.capital","D_elas=0,PF(\"l\")=1"] #  1.0804862134586
    @test MPSGE.Complementarity.result_value(m._jump_model[:Y]) ≈ two_by_two_jpmge["Y._","D_elas=0,PF(\"l\")=1"] #  6.56097242691719
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]ρY")]) ≈ two_by_two_jpmge["PY.g1","D_elas=0,PF(\"l\")=1"] #  2.13160911430459
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]ρY")]) ≈ two_by_two_jpmge["PY.g2","D_elas=0,PF(\"l\")=1"] #  4.26321822860918
    
    # Implicit variables don't match
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s1]")]) ≈ two_by_two_jpmge["g1.s1","D_elas=0,PF(\"l\")=1"] #  6.07043510191547
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s1]")]) ≈ two_by_two_jpmge["g2.s1","D_elas=0,PF(\"l\")=1"] #  2.22456726454906
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s2]")]) ≈ two_by_two_jpmge["g1.s2","D_elas=0,PF(\"l\")=1"] #  1.98493348461053
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s2]")]) ≈ two_by_two_jpmge["g2.s2","D_elas=0,PF(\"l\")=1"] #  10.9109593745066
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s1]")]) ≈ two_by_two_jpmge["labor.s1","D_elas=0,PF(\"l\")=1"] #  1.04145864038272
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s1]")]) ≈ two_by_two_jpmge["capital.s1","D_elas=0,PF(\"l\")=1"] #  3.35854135960791
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s2]")]) ≈ two_by_two_jpmge["labor.s2","D_elas=0,PF(\"l\")=1"] #  0.963879619573346
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s2]")]) ≈ two_by_two_jpmge["capital.s2","D_elas=0,PF(\"l\")=1"] #  1.03612038042804
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s1]")]) ≈ two_by_two_jpmge["g1.s1","D D_elas=0,PF(\"l\")=1"] #  4.00877896925268
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s2]")]) ≈ two_by_two_jpmge["g1.s2","D D_elas=0,PF(\"l\")=1"] #  2.15461428290835
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s1]")]) ≈ two_by_two_jpmge["g2.s1","D D_elas=0,PF(\"l\")=1"] #  2.04331217808598
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s2]")]) ≈ two_by_two_jpmge["g2.s2","D D_elas=0,PF(\"l\")=1"] #  6.58936245242578
       
    #A replication of the JPMGE from https://www.gams.com/34/docs/UG_MPSGE_Intro.html#UG_MPSGE_Intro_Appendix_jpmge
    # Re-running the model and tests as checks on different Demand elasticities - here with Demand elasticity = 2. (A CES example)
    m = Model()
    goods = [:g1, :g2]
    factors = [:l, :k]
    sectors = [:s1, :s2]
    make0 = DenseAxisArray(Float64[6 2; 2 10], goods, sectors)
    use0 = DenseAxisArray(Float64[4 2; 2 6], goods, sectors)
    fd0 = DenseAxisArray(Float64[1 3; 1 1], factors, sectors)
    c0 = DenseAxisArray(Float64[2, 4], goods)
    e0 = DenseAxisArray(Float64[sum(fd0[f,:]) for f in factors], factors)
# All indices and data as above
    endow = add!(m, Parameter(:endow, indices=(factors,), value=1.0)) 
    X = add!(m, Sector(:X, indices=(sectors,)))
    P = add!(m, Commodity(:P, indices=(goods,)))
    PF = add!(m, Commodity(:PF, indices=(factors,)))
    Y = add!(m, Consumer(:Y, benchmark=sum(fd0)))#example 4 has sum e0
    for j in sectors
        @production(m, X[j], 1, 1, [Output(P[i], make0[i,j]) for i in goods], [[Input(P[i], use0[i,j]) for i in goods]; [Input(PF[f], fd0[f,j]) for f in factors]])
    end

    @demand(m, Y, 2., [Demand(P[i], c0[i]) for i in goods], [Endowment(PF[:k], :($(endow[:k]) * $(e0[:k]))), Endowment(PF[:l], :($(endow[:l]) * $(e0[:l])))])

    avm = algebraic_version(m)
    @test typeof(avm) == MPSGE.AlgebraicWrapper

    solve!(m)

    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s1]) ≈ 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s2]) ≈ 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g1]) ≈ 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g2]) ≈ 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:l]) ≈ 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:k]) ≈ 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[:Y]) ≈ 6.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s1]")]) ≈ 6.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s1]")]) ≈ 2.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s2]")]) ≈ 2.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s2]")]) ≈10.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s1]")]) ≈ 4.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s1]")]) ≈ 2.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s1]")]) ≈ 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s1]")]) ≈ 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s2]")]) ≈ 2.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s2]")]) ≈ 6.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s2]")]) ≈ 3.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s2]")]) ≈ 1.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]ρY")]) ≈ 2.
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]ρY")]) ≈ 4.

    #Counter-factual 1, labour supply increased by 10%
    set_value(endow[:l], 1.1*get_value(endow[:l]))
    set_fixed!(Y, true)

    solve!(m)

    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s1]) ≈ two_by_two_jpmge["X.s1","D_elas=2,Y=6.4"] #  0.987856533434743
    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s2]) ≈ two_by_two_jpmge["X.s2","D_elas=2,Y=6.4"] #  1.10437048613337
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g1]) ≈ two_by_two_jpmge["P.g1","D_elas=2,Y=6.4"] #  1.01249987524684
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g2]) ≈ two_by_two_jpmge["P.g2","D_elas=2,Y=6.4"] #  0.994953167286117
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:l]) ≈ two_by_two_jpmge["PF.labor","D_elas=2,Y=6.4"] #  0.977738693937376
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:k]) ≈ two_by_two_jpmge["PF.capital","D_elas=2,Y=6.4"] #  1.0489748733372
    @test MPSGE.Complementarity.result_value(m._jump_model[:Y]) ≈ two_by_two_jpmge["Y._","D_elas=2,Y=6.4"] #  6.4
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]ρY")]) ≈ two_by_two_jpmge["PY.g1","D_elas=2,Y=6.4"] #  2.08251175868134
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]ρY")]) ≈ two_by_two_jpmge["PY.g2","D_elas=2,Y=6.4"] #  4.31322523032984
    
    # Implicit variables don't match
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s1]")]) ≈ two_by_two_jpmge["g1.s1","D_elas=2,Y=6.4"] #  5.95276133067175
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s1]")]) ≈ two_by_two_jpmge["g2.s1","D_elas=2,Y=6.4"] #  2.2410583217899
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s2]")]) ≈ two_by_two_jpmge["g1.s2","D_elas=2,Y=6.4"] #  1.94986649211727
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s2]")]) ≈ two_by_two_jpmge["g2.s2","D_elas=2,Y=6.4"] #  11.0111029633173
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s1]")]) ≈ two_by_two_jpmge["labor.s1","D_elas=2,Y=6.4"] #  1.01857428730682
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s1]")]) ≈ two_by_two_jpmge["capital.s1","D_elas=2,Y=6.4"] #  3.38142571269311
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s2]")]) ≈ two_by_two_jpmge["labor.s2","D_elas=2,Y=6.4"] #  0.949402620275564
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s2]")]) ≈ two_by_two_jpmge["capital.s2","D_elas=2,Y=6.4"] #  1.05059737972454
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s1]")]) ≈ two_by_two_jpmge["g1.s1","D D_elas=2,Y=6.4"] #  3.93441823627591
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s2]")]) ≈ two_by_two_jpmge["g1.s2","D D_elas=2,Y=6.4"] #  2.17688965750493
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s1]")]) ≈ two_by_two_jpmge["g2.s1","D D_elas=2,Y=6.4"] #  2.00190225247692
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s2]")]) ≈ two_by_two_jpmge["g2.s2","D D_elas=2,Y=6.4"] #  6.64584197262839
       
    # Counter-factual 2, use Price of good 1 as the numeraire
    set_fixed!(Y,false)
    set_fixed!(P[:g1], true)
    solve!(m)

    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s1]) ≈ two_by_two_jpmge["X.s1","D_elas=2,P(\"g1\")=1"] #  0.987856539834064
    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s2]) ≈ two_by_two_jpmge["X.s2","D_elas=2,P(\"g1\")=1"] #  1.10437048704423
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g1]) ≈ two_by_two_jpmge["P.g1","D_elas=2,P(\"g1\")=1"] #  1
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g2]) ≈ two_by_two_jpmge["P.g2","D_elas=2,P(\"g1\")=1"] #  0.982669909969397
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:l]) ≈ two_by_two_jpmge["PF.labor","D_elas=2,P(\"g1\")=1"] #  0.965667951333231
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:k]) ≈ two_by_two_jpmge["PF.capital","D_elas=2,P(\"g1\")=1"] #  1.03602468782686
    @test MPSGE.Complementarity.result_value(m._jump_model[:Y]) ≈ two_by_two_jpmge["Y._","D_elas=2,P(\"g1\")=1"] #  6.32098836151993
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]ρY")]) ≈ two_by_two_jpmge["PY.g1","D_elas=2,P(\"g1\")=1"] atol = 1.0e-7 #  2.08251172661481
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]ρY")]) ≈ two_by_two_jpmge["PY.g2","D_elas=2,P(\"g1\")=1"] #  4.31322521622456
    
    # Implicit variables don't match
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s1]")]) ≈ two_by_two_jpmge["g1.s1","D_elas=2,P(\"g1\")=1"] #  5.9527613780233
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s1]")]) ≈ two_by_two_jpmge["g2.s1","D_elas=2,P(\"g1\")=1"] #  2.24105833489612
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s2]")]) ≈ two_by_two_jpmge["g1.s2","D_elas=2,P(\"g1\")=1"] #  1.94986649580382
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s2]")]) ≈ two_by_two_jpmge["g2.s2","D_elas=2,P(\"g1\")=1"] #  11.0111029609427
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s1]")]) ≈ two_by_two_jpmge["labor.s1","D_elas=2,P(\"g1\")=1"] #  1.01857430408564
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s1]")]) ≈ two_by_two_jpmge["capital.s1","D_elas=2,P(\"g1\")=1"] #  3.38142573906514
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s2]")]) ≈ two_by_two_jpmge["labor.s2","D_elas=2,P(\"g1\")=1"] #  0.949402628204007
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s2]")]) ≈ two_by_two_jpmge["capital.s2","D_elas=2,P(\"g1\")=1"] #  1.05059737938542
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s1]")]) ≈ two_by_two_jpmge["g1.s1","D D_elas=2,P(\"g1\")=1"] #  3.93441824602821
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s2]")]) ≈ two_by_two_jpmge["g1.s2","D D_elas=2,P(\"g1\")=1"] #  2.17688964401899
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s1]")]) ≈ two_by_two_jpmge["g2.s1","D D_elas=2,P(\"g1\")=1"] #  2.00190226957837
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s2]")]) ≈ two_by_two_jpmge["g2.s2","D D_elas=2,P(\"g1\")=1"] #  6.64584197175667
                
    # Counter-factual 3, use price of labour (wages) as the numeraire
    set_fixed!(P[:g1], false)
    set_fixed!(PF[:l], true)
    solve!(m)

    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s1]) ≈ two_by_two_jpmge["X.s1","D_elas=2,PF(\"l\")=1"] #  0.987856533434658
    @test MPSGE.Complementarity.result_value(m._jump_model[:X][:s2]) ≈ two_by_two_jpmge["X.s2","D_elas=2,PF(\"l\")=1"] #  1.10437048613261
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g1]) ≈ two_by_two_jpmge["P.g1","D_elas=2,PF(\"l\")=1"] #  1.03555262927088
    @test MPSGE.Complementarity.result_value(m._jump_model[:P][:g2]) ≈ two_by_two_jpmge["P.g2","D_elas=2,PF(\"l\")=1"] #  1.01760641514489
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:l]) ≈ two_by_two_jpmge["PF.labor","D_elas=2,PF(\"l\")=1"] #  1
    @test MPSGE.Complementarity.result_value(m._jump_model[:PF][:k]) ≈ two_by_two_jpmge["PF.capital","D_elas=2,PF(\"l\")=1"] #  1.07285809576816
    @test MPSGE.Complementarity.result_value(m._jump_model[:Y]) ≈ two_by_two_jpmge["Y._","D_elas=2,PF(\"l\")=1"] #  6.54571619153633
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]ρY")]) ≈ two_by_two_jpmge["PY.g1","D_elas=2,PF(\"l\")=1"] #  2.08251175868083
    @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]ρY")]) ≈ two_by_two_jpmge["PY.g2","D_elas=2,PF(\"l\")=1"] #  4.31322523032828
    # Implicit variables don't match
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s1]")]) ≈ two_by_two_jpmge["g1.s1","D_elas=2,PF(\"l\")=1"] #  5.95276133067115
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s1]")]) ≈ two_by_two_jpmge["g2.s1","D_elas=2,PF(\"l\")=1"] #  2.24105832178826
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]‡X[s2]")]) ≈ two_by_two_jpmge["g1.s2","D_elas=2,PF(\"l\")=1"] #  1.94986649211719
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]‡X[s2]")]) ≈ two_by_two_jpmge["g2.s2","D_elas=2,PF(\"l\")=1"] #  11.0111029633099
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s1]")]) ≈ two_by_two_jpmge["labor.s1","D_elas=2,PF(\"l\")=1"] #  1.01857428730657
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s1]")]) ≈ two_by_two_jpmge["capital.s1","D_elas=2,PF(\"l\")=1"] #  3.38142571269045
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[l]†X[s2]")]) ≈ two_by_two_jpmge["labor.s2","D_elas=2,PF(\"l\")=1"] #  0.949402620275962
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("PF[k]†X[s2]")]) ≈ two_by_two_jpmge["capital.s2","D_elas=2,PF(\"l\")=1"] #  1.05059737972441
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s1]")]) ≈ two_by_two_jpmge["g1.s1","D D_elas=2,PF(\"l\")=1"] #  3.93441823627541
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g1]†X[s2]")]) ≈ two_by_two_jpmge["g1.s2","D D_elas=2,PF(\"l\")=1"] #  2.17688965750347
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s1]")]) ≈ two_by_two_jpmge["g2.s1","D D_elas=2,PF(\"l\")=1"] #  2.00190225247655
    # @test MPSGE.Complementarity.result_value(m._jump_model[Symbol("P[g2]†X[s2]")]) ≈ two_by_two_jpmge["g2.s2","D D_elas=2,PF(\"l\")=1"] #  6.64584197262353
   
end
