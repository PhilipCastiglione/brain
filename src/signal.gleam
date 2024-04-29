import gleam/erlang/process.{type Subject}

pub type Signal {
  SensorSignal
  NeuronSignal(signal: Int)
  // EffectorSignal(output: String)
  AddInwardConnection(neuron: Subject(Signal))
  AddOutwardConnection(neuron: Subject(Signal))
}
