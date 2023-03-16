using Distributed

using Oscar

#function addprocs(machines::AbstractVector; tunnel=false, sshflags=``, max_parallel=10, kwargs...)
#    new = Distributed.addprocs(
#        Distributed.SSHManager(machines);
#        tunnel=tunnel, sshflags=sshflags, max_parallel=max_parallel, kwargs...)
#
#    for d = new
#        eval(Main, :(@spawnat $d eval(Main, :(include(pathof(Oscar))))))
#    end
#    return new
#end
#

addprocs(4)

@everywhere begin
    using Pkg
    Pkg.activate(@__DIR__)
    Pkg.instantiate()
end
@everywhere begin
    using Oscar
end

const jobs = Distributed.RemoteChannel(() -> Channel{Int}(32));
const results = Distributed.RemoteChannel(() -> Channel{Tuple}(32));

@everywhere function do_work(jobs, results) # define work function everywhere
    for i in 1:10
        job_id = take!(jobs)
        exec_time = rand()
        print(exec_time) # simulates elapsed time doing actual work
        put!(results, (job_id, exec_time, myid()))
    end
end

function make_jobs(n)
    io = IOStream("test")
    for i in 1:n
        put!(jobs, io)
    end
end;

n = 5

errormonitor(@async make_jobs(n)); # feed the jobs channel with "n" jobs

for p in workers() # start tasks on the workers to process requests in parallel
    remote_do(do_work, p, jobs, results)
end

@elapsed while n > 0 # print out results
    job_id, exec_time, where = take!(results)
    println("$job_id finished in $(round(exec_time; digits=2)) seconds on worker $where")
    global n = n - 1
end

