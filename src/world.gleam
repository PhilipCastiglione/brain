import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import signal.{type Signal}

pub type NeuronMessage {
  Observe(sensor: Subject(Signal))
  Sense(reply: Subject(String))
  Effect(output: Int)
}

pub type MonitorMessage {
  Experiment(reply: Subject(Int))
}

pub type Message {
  Internal(NeuronMessage)
  External(MonitorMessage)
}

type State {
  State(sensors: List(Subject(Signal)), output: Option(Subject(Int)))
}

fn handle_message(message: Message, state: State) {
  case message {
    Internal(Observe(sensor)) ->
      actor.continue(State(..state, sensors: [sensor, ..state.sensors]))
    Internal(Sense(reply)) -> {
      actor.send(reply, "Hello lol")
      actor.continue(state)
    }
    Internal(Effect(output)) -> {
      io.println("***Significant brain output!***")
      case state.output {
        Some(reply) -> actor.send(reply, output)
        _ -> Nil
      }
      actor.continue(State(..state, output: None))
    }
    External(Experiment(reply)) -> {
      io.println("***Beginning experiment***")
      state.sensors
      |> list.each(actor.send(_, signal.SensorSignal))
      actor.continue(State(..state, output: Some(reply)))
    }
  }
}

pub fn start(parent: Subject(Subject(MonitorMessage))) {
  actor.start_spec(actor.Spec(
    init: fn() {
      let internal_api = process.new_subject()
      let external_api = process.new_subject()
      process.send(parent, external_api)

      let message_selector =
        process.new_selector()
        |> process.selecting(internal_api, Internal(_))
        |> process.selecting(external_api, External(_))

      actor.Ready(State([], None), message_selector)
    },
    init_timeout: 1000,
    loop: handle_message,
  ))
}
