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
const jobs = Distributed.RemoteChannel(() -> Channel{MatElem}(10));
const results = Distributed.RemoteChannel(() -> Channel{Tuple}(32));

@everywhere function do_work(rings, jobs, results) # define work function everywhere
    Qx = take!(rings)
    F = take!(rings)
    MR = take!(rings)
    
    for i in 1:10
        m = take!(jobs)
        put!(results, (det(m), myid()))
    end
end

function make_jobs(n)
    Qx, x = QQ["x"]
    F, a = number_field(x^2 + x + 1)
    MR = matrix_space(F, 2, 2)
    put!(rings, Qx)
    put!(rings, F)
    put!(rings, MR)
    
    for i in 1:n
        put!(jobs, MR(Matrix{elem_type(F)}([a^i F(0); a^(i - 2) F(1)])))
    end
end;

n = 5

errormonitor(@async make_jobs(n)); # feed the jobs channel with "n" jobs

for p in workers() # start tasks on the workers to process requests in parallel
    remote_do(do_work, p, rings, jobs, results)
end

global total = identity_matrix(QQ, 2)

@elapsed while n > 0 # print out results
    determinant, worker = take!(results)
    global n = n - 1
    total *= determinant
end
