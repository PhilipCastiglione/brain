import gleam/erlang/process.{type Subject}
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/otp/supervisor.{Spec, add, worker}
import neuron.{
  AddOutwardConnection, EffectorNeuron, Interneuron, SensorSignal, SensoryNeuron,
}

// helper function to collect the started children
// i have no idea whether this is a good way to get the children out, 
// but it would scale to multiple actor types using supervisor.returning
fn get_neurons(
  selector: process.Selector(Option(Subject(neuron.Message))),
) -> List(Subject(neuron.Message)) {
  case process.select_forever(selector) {
    None -> []
    Some(neuron) -> [neuron, ..get_neurons(selector)]
  }
}

// create neurons, with just a single supervisor for now
fn grow_brain() -> List(Subject(neuron.Message)) {
  let receive_neuron = process.new_subject()
  let receive_end = process.new_subject()

  let channel =
    process.new_selector()
    |> process.selecting(receive_neuron, fn(n) { Some(n) })
    |> process.selecting(receive_end, fn(_) { None })

  let assert Ok(_) =
    supervisor.start_spec(Spec(
      init: fn(children) {
        children
        |> add(worker(neuron.start(_, SensoryNeuron, 10)))
        |> add(worker(neuron.start(_, Interneuron, 10)))
        |> add(worker(neuron.start(_, Interneuron, 10)))
        |> add(worker(neuron.start(_, EffectorNeuron, 10)))
      },
      argument: receive_neuron,
      max_frequency: 1,
      frequency_period: 5,
    ))

  process.send(receive_end, Nil)
  get_neurons(channel)
}

fn run_experiment(neurons: List(Subject(neuron.Message))) {
  let assert [sensory_neuron, interneuron_1, interneuron_2, effector_neuron] =
    neurons

  actor.send(sensory_neuron, AddOutwardConnection(interneuron_1))
  actor.send(interneuron_1, AddOutwardConnection(interneuron_2))
  actor.send(interneuron_2, AddOutwardConnection(effector_neuron))
  actor.send(sensory_neuron, SensorSignal("Hello lol"))

  process.sleep_forever()
}

// run everything outside the main process, so that we can log top-level errors
pub fn main() {
  process.trap_exits(True)

  process.start(
    fn() {
      let neurons = grow_brain()
      run_experiment(neurons)
    },
    linked: True,
  )

  process.sleep_forever()
}
