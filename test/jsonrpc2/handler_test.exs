defmodule JSONRPC2.HandlerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  describe "examples from JSON-RPC 2.0 spec at http://www.jsonrpc.org/specification#examples" do
    test "rpc call with positional parameters" do
      assert_rpc_reply(JSONRPC2.SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "subtract", "params": [42, 23], "id": 1}),
        ~s({"jsonrpc": "2.0", "result": 19, "id": 1})
      )

      assert_rpc_reply(JSONRPC2.SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "subtract", "params": [23, 42], "id": 2}),
        ~s({"jsonrpc": "2.0", "result": -19, "id": 2})
      )
    end

    test "rpc call with named parameters" do
      assert_rpc_reply(JSONRPC2.SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "subtract", "params": {"subtrahend": 23, "minuend": 42}, "id": 3}),
        ~s({"jsonrpc": "2.0", "result": 19, "id": 3})
      )

      assert_rpc_reply(JSONRPC2.SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "subtract", "params": {"minuend": 42, "subtrahend": 23}, "id": 4}),
        ~s({"jsonrpc": "2.0", "result": 19, "id": 4})
      )
    end

    test "a Notification" do
      assert_rpc_noreply(JSONRPC2.SpecHandler, ~s({"jsonrpc": "2.0", "method": "update", "params": [1,2,3,4,5]}))
      assert_rpc_noreply(JSONRPC2.SpecHandler, ~s({"jsonrpc": "2.0", "method": "foobar"}))
    end

    test "rpc call of non-existent method" do
      assert_rpc_reply(JSONRPC2.SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "foobar", "id": "1"}),
        ~s({"jsonrpc": "2.0", "error": {"code": -32601, "message": "Method not found"}, "id": "1"})
      )
    end

    test "rpc call with invalid JSON" do
      assert_rpc_reply(JSONRPC2.SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "foobar, "params": "bar", "baz]),
        ~s({"jsonrpc": "2.0", "error": {"code": -32700, "message": "Parse error"}, "id": null})
      )
    end

    test "rpc call with invalid Request object" do
      assert_rpc_reply(JSONRPC2.SpecHandler,
        ~s({"jsonrpc": "2.0", "method": 1, "params": "bar"}),
        ~s({"jsonrpc": "2.0", "error": {"code": -32600, "message": "Invalid Request"}, "id": null})
      )
    end

    test "rpc call Batch, invalid JSON" do
      assert_rpc_reply(JSONRPC2.SpecHandler,
        ~s([
          {"jsonrpc": "2.0", "method": "sum", "params": [1,2,4], "id": "1"},
          {"jsonrpc": "2.0", "method"
        ]),
        ~s({"jsonrpc": "2.0", "error": {"code": -32700, "message": "Parse error"}, "id": null})
      )
    end

    test "rpc call with an empty Array" do
      assert_rpc_reply(JSONRPC2.SpecHandler,
        ~s([]),
        ~s({"jsonrpc": "2.0", "error": {"code": -32600, "message": "Invalid Request"}, "id": null})
      )
    end

    test "rpc call with an invalid Batch (but not empty)" do
      assert_rpc_reply(JSONRPC2.SpecHandler,
        ~s([1]),
        ~s([
          {"jsonrpc": "2.0", "error": {"code": -32600, "message": "Invalid Request"}, "id": null}
        ])
      )
    end

    test "rpc call with invalid Batch" do
      assert_rpc_reply(JSONRPC2.SpecHandler,
        ~s([1,2,3]),
        ~s([
          {"jsonrpc": "2.0", "error": {"code": -32600, "message": "Invalid Request"}, "id": null},
          {"jsonrpc": "2.0", "error": {"code": -32600, "message": "Invalid Request"}, "id": null},
          {"jsonrpc": "2.0", "error": {"code": -32600, "message": "Invalid Request"}, "id": null}
        ])
      )
    end

    test "rpc call Batch" do
      assert_rpc_reply(JSONRPC2.SpecHandler,
        ~s([
            {"jsonrpc": "2.0", "method": "sum", "params": [1,2,4], "id": "1"},
            {"jsonrpc": "2.0", "method": "notify_hello", "params": [7]},
            {"jsonrpc": "2.0", "method": "subtract", "params": [42,23], "id": "2"},
            {"foo": "boo"},
            {"jsonrpc": "2.0", "method": "foo.get", "params": {"name": "myself"}, "id": "5"},
            {"jsonrpc": "2.0", "method": "get_data", "id": "9"}
        ]),
        ~s([
            {"jsonrpc": "2.0", "result": 7, "id": "1"},
            {"jsonrpc": "2.0", "result": 19, "id": "2"},
            {"jsonrpc": "2.0", "error": {"code": -32600, "message": "Invalid Request"}, "id": null},
            {"jsonrpc": "2.0", "error": {"code": -32601, "message": "Method not found"}, "id": "5"},
            {"jsonrpc": "2.0", "result": ["hello", 5], "id": "9"}
        ])
      )
    end

    test "rpc call Batch (all notifications)" do
      assert_rpc_noreply(JSONRPC2.SpecHandler,
        ~s([
          {"jsonrpc": "2.0", "method": "notify_sum", "params": [1,2,4]},
          {"jsonrpc": "2.0", "method": "notify_hello", "params": [7]}
        ])
      )
    end
  end

  describe "internal tests" do
    test "rpc call exit/raise/throw produces internal error" do
      capture =
        capture_log fn ->
          assert_rpc_reply(JSONRPC2.ErrorHandler,
            ~s([
                {"jsonrpc": "2.0", "method": "exit", "id": "1"},
                {"jsonrpc": "2.0", "method": "raise", "id": "2"},
                {"jsonrpc": "2.0", "method": "throw", "id": "3"}
            ]),
            ~s([
                {"jsonrpc": "2.0", "id": "1", "error": {"message": "Internal error", "code": -32603}},
                {"jsonrpc": "2.0", "id": "2", "error": {"message": "Internal error", "code": -32603}},
                {"jsonrpc": "2.0", "id": "3", "error": {"message": "Internal error", "code": -32603}}
              ])
          )
        end

      assert capture =~ "[error] Error in handler JSONRPC2.ErrorHandler for method exit with params: []:"
      assert capture =~ "[error] Error in handler JSONRPC2.ErrorHandler for method raise with params: []:"
      assert capture =~ "[error] Error in handler JSONRPC2.ErrorHandler for method throw with params: []:"
    end

    test "rpc call with invalid response" do
      capture =
        capture_log fn ->
          assert_rpc_reply(JSONRPC2.ErrorHandler,
            ~s({"jsonrpc": "2.0", "method": "bad_reply", "id": "1"}),
            ~s({"jsonrpc": "2.0", "error": {"code": -32603, "message": "Internal error"}, "id": null})
          )
        end

      assert capture =~ "[info]  Handler JSONRPC2.ErrorHandler returned invalid reply:"
    end

    test "throwable errors" do
      assert_rpc_reply(JSONRPC2.ErrorHandler,
        ~s({"jsonrpc": "2.0", "method": "method_not_found", "id": "1"}),
        ~s({"jsonrpc": "2.0", "error": {"code": -32601, "message": "Method not found"}, "id": "1"})
      )

      assert_rpc_reply(JSONRPC2.ErrorHandler,
        ~s({"jsonrpc": "2.0", "method": "invalid_params", "params": ["bad"], "id": "1"}),
        ~s({"jsonrpc": "2.0", "error": {"code": -32602, "message": "Invalid params", "data": ["bad"]}, "id": "1"})
      )

      assert_rpc_reply(JSONRPC2.ErrorHandler,
        ~s({"jsonrpc": "2.0", "method": "custom_error", "id": "1"}),
        ~s({"jsonrpc": "2.0", "error": {"code": 404, "message": "Custom not found error"}, "id": "1"})
      )

      assert_rpc_reply(JSONRPC2.ErrorHandler,
        ~s({"jsonrpc": "2.0", "method": "custom_error", "params": ["bad"], "id": "1"}),
        ~s({"jsonrpc": "2.0", "error": {"code": 404, "message": "Custom not found error", "data": ["bad"]}, "id": "1"})
      )
    end
  end

  defp assert_rpc_reply(handler, call, expected_reply) do
    assert {:reply, reply} = handler.handle(call)
    assert JSONRPC2.Serializers.Jiffy.decode(reply) == JSONRPC2.Serializers.Jiffy.decode(expected_reply)
  end

  defp assert_rpc_noreply(handler, call) do
    assert :noreply == handler.handle(call)
  end
end
