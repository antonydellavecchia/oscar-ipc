using Distributed

addprocs(1)

@everywhere begin
    using Pkg
    Pkg.activate(@__DIR__)
    Pkg.instantiate()
end

@everywhere begin
    using Revise, Oscar
end

const rings = Distributed.RemoteChannel(() -> Channel{Any}(10));
const jobs = Distributed.RemoteChannel(() -> Channel{FieldElem}(10));
const results = Distributed.RemoteChannel(() -> Channel{FieldElem}(32));

@everywhere function do_work(rings, jobs, results) # define work function everywhere
    Qx = take!(rings)
    F = take!(rings)

    println("taking m")
    m = take!(jobs)
    
    println(F == parent(m))

    for i in 1:10
        println(Qx, F)
    
        put!(results, m^2)
    end
end


function make_jobs(n)
    Qx, x = QQ["x"]
    F, a = number_field(x^2 + x + 1)
    put!(rings, Qx)
    put!(rings, F)

    println("main")
    println(Oscar.global_serializer_state.id_to_obj)
    for i in 1:n
        m = a^i
        put!(jobs, m)
        println(Oscar.global_serializer_state.obj_to_id[parent(m)])
        println(Oscar.global_serializer_state.obj_to_id[F])
        println(F == parent(m))
    end
end;

n = 5

errormonitor(@async make_jobs(n)); # feed the jobs channel with "n" jobs

for p in workers() # start tasks on the workers to process requests in parallel
    remote_do(do_work, p, rings, jobs, results)
end

#global total = identity_matrix(QQ, 2)
#
#@elapsed while n > 0 # print out results
#    determinant, worker = take!(results)
#    global n = n - 1
#    total *= determinant
#end
#
