using CommonSolve
using SymbolicIndexingInterface

@kwdef struct PDEComponent <: AbstractTimeDependentComponent
    model::ODEProblem
    name::String = "PDE Component"
    state_names::Dict{String,Any} = Dict{String,Any}() # Dictionary that maps state names (given as strings) to their corresponding indices in the state vector (or symbols for MTK)
    time_step::Float64 = 1.0
    alg = Rodas5()
    intkwargs::Tuple = ()
end

@kwdef mutable struct PDEComponentIntegrator <: ComponentIntegrator
    integrator::OrdinaryDiffEqCore.ODEIntegrator
    component::PDEComponent
    outputs::Dict{ConnectedVariable,Any} = Dict{ConnectedVariable,Any}()
    inputs::Dict{ConnectedVariable,Any} = Dict{ConnectedVariable,Any}()
end

function CommonSolve.init(c::PDEComponent, conns::Vector{Connector})
    integrator = PDEComponentIntegrator(integrator = init(c.model, c.alg; dt=c.time_step, c.intkwargs...), component = c)
    inputs, outputs = inputsandoutputs(integrator, conns)
    integrator.inputs = inputs
    integrator.outputs = outputs
    return integrator
end

function CommonSolve.step!(compInt::PDEComponentIntegrator)
    for (key, value) in compInt.inputs
        setstate!(compInt, key, value)
    end
    u_modified!(compInt.integrator, true)
    CommonSolve.step!(compInt.integrator, compInt.component.time_step, true)
end

function getstate(compInt::PDEComponentIntegrator, key)
    if isnothing(key.variableindex)
        # No index for variable
        index = compInt.component.state_names[key.variable]
        return compInt.integrator[index]
    else
        index = compInt.component.state_names[key.variable]
        return compInt.integrator[index][key.variableindex]
    end
end

function getstate(compInt::PDEComponentIntegrator)
    # Return the full state vector
    return compInt.integrator.u
end

function setstate!(compInt::PDEComponentIntegrator, key, value)
    if isnothing(key.variableindex)
        # No index for variable
        index = compInt.component.state_names[key.variable]
        compInt.integrator[index] = value
    else key.variableindex isa AbstractVector
        # Single index for one variable
        index = compInt.component.state_names[key.variable]
        if length(index[key.variableindex]) == 1
            # If the index is a single value, set it directly
            compInt.integrator.u[(index)[key.variableindex][1]] = value
        else
            # If the index is a vector, set the corresponding values
            compInt.integrator.u[(index)[key.variableindex]] .= value
        end
    end
end

function setstate!(compInt::PDEComponentIntegrator, value)
    # Set the full state vector
    compInt.integrator.u = value
end

function gettime(compInt::PDEComponentIntegrator)
    return compInt.integrator.t
end

function settime!(compInt::PDEComponentIntegrator, t)
    u_modified!(compInt.integrator, true)
    compInt.integrator.t = t
end

function variables(component::PDEComponent)
    return keys(component.state_names)
end
