import gleam/erlang/process.{type Subject}
import gleam/function.{identity}
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import signal.{
  type Signal, AddInwardConnection, AddOutwardConnection, NeuronSignal,
  SensorSignal,
}
import world.{Effect, Observe, Sense}

// these could be different actors in future
pub type Kind {
  SensoryNeuron
  Interneuron
  EffectorNeuron
}

type State {
  State(
    threshold: Int,
    kind: Kind,
    inward_connections: List(Subject(Signal)),
    outward_connections: List(Subject(Signal)),
    world: Subject(world.NeuronMessage),
  )
}

fn handle_message(signal: Signal, state: State) {
  case signal {
    SensorSignal -> {
      case state.kind {
        SensoryNeuron -> {
          case process.try_call(state.world, Sense, 1000) {
            Ok(input) -> {
              io.debug("Received sensor signal:" <> input)
              list.each(state.outward_connections, actor.send(_, NeuronSignal(2)))
              actor.continue(state)
            }
            _ -> {
              io.debug("sensory timeout")
              actor.continue(state)
            }
          }
        }
        _ -> {
          io.debug("Received sensor signal but I'm not a sensory neuron")
          actor.continue(state)
        }
      }
    }
    NeuronSignal(signal) -> {
      case state.kind {
        SensoryNeuron -> {
          io.debug("Received neuron signal but I'm a sensory neuron")
          actor.continue(state)
        }
        Interneuron -> {
          io.debug("Received neuron signal:" <> int.to_string(signal))
          list.each(state.outward_connections, actor.send(_, NeuronSignal(1)))
          actor.continue(state)
        }
        EffectorNeuron -> {
          io.debug("Received neuron signal:" <> int.to_string(signal))
          actor.send(state.world, Effect(signal))
          actor.continue(state)
        }
      }
    }
    AddInwardConnection(neuron) -> {
      io.debug("Adding inward connection")
      io.debug(neuron)
      actor.continue(
        State(..state, inward_connections: [neuron, ..state.inward_connections]),
      )
    }
    AddOutwardConnection(neuron) -> {
      io.debug("Adding outward connection")
      io.debug(neuron)
      actor.continue(
        State(
          ..state,
          outward_connections: [neuron, ..state.outward_connections],
        ),
      )
    }
  }
}

pub fn start(
  subjects: #(Subject(Subject(Signal)), Subject(world.NeuronMessage)),
  kind: Kind,
  threshold: Int,
) {
  let #(parent, world) = subjects
  actor.start_spec(actor.Spec(
    init: fn() {
      let self = process.new_subject()
      process.send(parent, self)

      let message_selector =
        process.new_selector()
        |> process.selecting(self, identity)

      case kind {
        SensoryNeuron -> {
          process.send(world, Observe(self))
        }
        _ -> Nil
      }

      actor.Ready(State(threshold, kind, [], [], world), message_selector)
    },
    init_timeout: 1000,
    loop: handle_message,
  ))
}
