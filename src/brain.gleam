import gleam/erlang/process.{type Subject}
import gleam/function.{identity}
import gleam/int
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/otp/supervisor.{Spec, add, returning, worker}
import gleam/string
import neuron.{EffectorNeuron, Interneuron, SensoryNeuron}
import signal.{type Signal, AddOutwardConnection}
import world.{Experiment}

// helper function to collect the started children
// i have no idea whether this is a good way to get the children out
fn get_neurons(
  selector: process.Selector(Option(Subject(Signal))),
) -> List(Subject(Signal)) {
  case process.select_forever(selector) {
    None -> []
    Some(neuron) -> [neuron, ..get_neurons(selector)]
  }
}

// create neurons, with just a single supervisor for now
fn grow_brain() {
  let receive_world = process.new_subject()
  let receive_neuron = process.new_subject()
  let receive_end = process.new_subject()

  let assert Ok(_) =
    supervisor.start_spec(Spec(
      init: fn(children) {
        children
        |> add(
          worker(world.start(_))
          |> returning(fn(_, self) { self }),
        )
        |> add(
          worker(actor.start(_, fn(message, state) {
            actor.send(state, world.Internal(message))
            actor.continue(state)
          }))
          |> returning(fn(_, self) { #(receive_neuron, self) }),
        )
        |> add(worker(neuron.start(_, SensoryNeuron, 10)))
        |> add(worker(neuron.start(_, Interneuron, 10)))
        |> add(worker(neuron.start(_, Interneuron, 10)))
        |> add(worker(neuron.start(_, EffectorNeuron, 10)))
      },
      argument: receive_world,
      max_frequency: 1,
      frequency_period: 5,
    ))

  process.send(receive_end, Nil)

  let neurons =
    process.new_selector()
    |> process.selecting(receive_neuron, Some(_))
    |> process.selecting(receive_end, fn(_) { None })
    |> get_neurons()

  let world =
    process.new_selector()
    |> process.selecting(receive_world, identity)
    |> process.select_forever()

  #(world, neurons)
}

fn run_experiment(
  world: Subject(world.MonitorMessage),
  neurons: List(Subject(Signal)),
) {
  let assert [sensory_neuron, interneuron_1, interneuron_2, effector_neuron] =
    neurons

  process.send(sensory_neuron, AddOutwardConnection(interneuron_1))
  process.send(interneuron_1, AddOutwardConnection(interneuron_2))
  process.send(interneuron_2, AddOutwardConnection(effector_neuron))

  process.call(world, Experiment(_), 100)
  |> int.to_string
  |> string.append("Result: ", _)
  |> io.println

  process.call(world, Experiment(_), 100)
  |> int.to_string
  |> string.append("Result: ", _)
  |> io.println
}

// run everything outside the main process, so that we can log top-level errors
pub fn main() {
  process.trap_exits(True)

  process.start(
    fn() {
      let #(world, neurons) = grow_brain()
      run_experiment(world, neurons)
    },
    linked: True,
  )

  process.new_selector()
  |> process.selecting_trapped_exits(fn(msg) {
    case msg.reason {
      process.Abnormal(reason) -> io.println(reason)
      _ -> Nil
    }
  })
  |> process.select_forever
}
