defmodule TodoMcpUiWeb.Utils.LvJs do

  def eval(text) do
    {value, _} =
      text
      |> Code.string_to_quoted!()
      |> locals_calls_only
      |> in_module(__MODULE__)
      |> Code.eval_quoted

    value
  end

  defp in_module(ast, mod) do
    quote do
      require unquote(Phoenix.LiveView.JS)
      import unquote(Phoenix.VerifiedRoutes)
      import unquote(mod)
      # prevent Kernel.exit and others to be in scope
      # only allow function from the given module
      import Kernel, only: []
      unquote(ast)
    end
  end

  defp locals_calls_only(ast) do
    ast
    |> Macro.prewalk(fn
      # dont allow remote function calls
      # evil = {{:., _, _}, _, _} ->
        # IO.inspect(c)
        # case c do
        #   [{:__aliases__, _, [:JS]}, _] -> evil
        #   _ ->
        #     IO.puts("warning: removed non local call #{inspect(evil)}")
        #     nil
        # end
        # IO.puts("warning: removed non local call #{inspect(evil)}")
        # nil

      # dont allow calling to eval and prevent loops
      {:eval, _, args} when is_list(args) ->
        IO.puts("warning: removed call to eval")
        nil

      # either raise or rewrite the code
      code -> code
    end)
  end
end
