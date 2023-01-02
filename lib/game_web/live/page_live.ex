defmodule GameWeb.PageLive do
  use GameWeb, :live_view

  def mount(_, _, socket) do
    {:ok, assign(socket, task: nil, result: nil)}
  end

  @impl true
  def handle_event("demo", _value, socket) do
    task =
      Task.async(fn ->
        Nx.Serving.batched_run(FizzBuzz, 15_432_115)
      end)

    {:noreply, assign(socket, task: task, result: nil)}
  end

  def handle_info({ref, prediction}, socket) when socket.assigns.task.ref == ref do
    result = prediction.result
    {:noreply, assign(socket, task: nil, result: result)}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div class="pb-4">make a fizzbuzz prediction for 15,432,115</div>
      <button
        type="button"
        phx-click="demo"
        class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
      >
        click me
      </button>
      <div class="pt-4 text-blue">result: <span class="font-bold"><%= @result %></span></div>
    </div>
    """
  end
end
