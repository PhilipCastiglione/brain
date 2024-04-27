import gleam/erlang/process.{type Subject}
import gleam/function.{identity}
import gleam/io
import gleam/list
import gleam/otp/actor

pub type Message {
  SensorSignal(input: String)
  NeuronSignal(signal: Int)
  // EffectorSignal(output: String)
  AddInwardConnection(neuron: Subject(Message))
  AddOutwardConnection(neuron: Subject(Message))
}

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
    inward_connections: List(Subject(Message)),
    outward_connections: List(Subject(Message)),
  )
}

fn handle_message(signal: Message, state: State) {
  case signal {
    SensorSignal(input) -> {
      case state.kind {
        SensoryNeuron -> {
          io.debug("Received sensor signal:")
          io.debug(input)
          list.each(state.outward_connections, actor.send(_, NeuronSignal(2)))
          actor.continue(state)
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
          io.debug("Received neuron signal:")
          io.debug(signal)
          list.each(state.outward_connections, actor.send(_, NeuronSignal(1)))
          actor.continue(state)
        }
        EffectorNeuron -> {
          io.debug("Received neuron signal:")
          io.debug(signal)
          io.println("***Significant brain output!***")
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

pub fn start(parent: Subject(Subject(Message)), kind: Kind, threshold: Int) {
  actor.start_spec(actor.Spec(
    init: fn() {
      let self = process.new_subject()
      process.send(parent, self)

      let message_selector =
        process.new_selector()
        |> process.selecting(self, identity)

      actor.Ready(State(threshold, kind, [], []), message_selector)
    },
    init_timeout: 1000,
    loop: handle_message,
  ))
}
