import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/list
import gleam/otp/actor

type Signal {
  SensorSignal(input: String)
  NeuronSignal(signal: Int)
  // EffectorSignal(output: String)
  AddInwardConnection(neuron: Subject(Signal))
  AddOutwardConnection(neuron: Subject(Signal))
}

type NeuronKind {
  SensoryNeuron
  Interneuron
  EffectorNeuron
}

type State {
  State(
    threshold: Int,
    kind: NeuronKind,
    inward_connections: List(Subject(Signal)),
    outward_connections: List(Subject(Signal)),
  )
}

fn handle_signal(signal: Signal, state: State) {
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

pub fn main() {
  io.println("Starting brain!")

  let assert Ok(sensory_neuron) =
    actor.start(State(10, SensoryNeuron, [], []), handle_signal)

  let assert Ok(interneuron_1) =
    actor.start(State(10, Interneuron, [], []), handle_signal)

  let assert Ok(interneuron_2) =
    actor.start(State(10, Interneuron, [], []), handle_signal)

  let assert Ok(effector_neuron) =
    actor.start(State(10, EffectorNeuron, [], []), handle_signal)

  actor.send(sensory_neuron, AddOutwardConnection(interneuron_1))
  actor.send(interneuron_1, AddOutwardConnection(interneuron_2))
  actor.send(interneuron_2, AddOutwardConnection(effector_neuron))

  // inward connections don't do anything yet

  actor.send(sensory_neuron, SensorSignal("Hello lol"))

  io.println("Main thread now sleeping forever...")

  process.sleep_forever()
}
