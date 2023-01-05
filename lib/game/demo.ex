defmodule Game.Demo do
  @moduledoc false

  alias Bumblebee.Shared

  def mods(x) do
    [rem(x, 3), rem(x, 5), rem(x, 15)]
  end

  def fizzbuzz(n) do
    cond do
      rem(n, 15) == 0 -> [0, 0, 1, 0]
      rem(n, 3) == 0 -> [1, 0, 0, 0]
      rem(n, 5) == 0 -> [0, 1, 0, 0]
      true -> [0, 0, 0, 1]
    end
  end

  def train_model() do
    data =
      1..1000
      |> Stream.map(fn n ->
        tensor = Nx.tensor([mods(n)])
        label = Nx.tensor([fizzbuzz(n)])
        {tensor, label}
      end)

    model =
      Axon.input("input", shape: {nil, 3})
      |> Axon.dense(10, activation: :relu)
      |> Axon.dense(4, activation: :softmax)

    params =
      model
      |> Axon.Loop.trainer(:categorical_cross_entropy, Axon.Optimizers.adamw(0.005))
      |> Axon.Loop.metric(:accuracy)
      |> Axon.Loop.run(data, %{}, epochs: 5, compiler: EXLA)

    model
    |> Axon.serialize(params)
    |> then(&File.write!("model.axon", &1))

    {model, params}
  end

  def maybe_train_model() do
    try do
      File.read!("model.axon") |> Axon.deserialize()
    rescue
      _ -> train_model()
    end
  end

  def load(opts) do
    {model, params} = maybe_train_model()

    {_init_fn, predict_fn} = Axon.build(model)

    scores_fun = fn params, input ->
      predict_fn.(params, input)
    end

    compile = opts[:compile]
    batch_size = compile[:batch_size]

    Nx.Serving.new(
      fn ->
        fn inputs ->
          inputs = Shared.maybe_pad(inputs, batch_size)
          scores_fun.(params, inputs)
        end
      end,
      batch_size: batch_size
    )
    |> Nx.Serving.client_preprocessing(fn input ->
      mod = Nx.tensor([mods(input)])

      {Nx.Batch.concatenate([mod]), true}
    end)
    |> Nx.Serving.client_postprocessing(fn prediction, _metadata, other ->
      result =
        case prediction |> Nx.argmax() |> Nx.to_flat_list() do
          [0] -> "fizz"
          [1] -> "buzz"
          [2] -> "fizzbuzz"
          [3] -> "womp"
        end

      %{result: result}
      |> Shared.normalize_output(other)
    end)
  end
end
