defmodule PusherClient.WSHandler do
  @moduledoc """
  Websocket Handler based on the Pusher Protocol: http://pusher.com/docs/pusher_protocol
  """
  require Lager
  alias PusherClient.PusherEvent

  defrecord WSHandlerInfo, gen_event_pid: nil, socket_id: nil do
    record_type gen_event_pid: pid, socket_id: nil | binary
  end

  @doc false
  def init(gen_event_pid, _conn_state) do
    { :ok, WSHandlerInfo.new(gen_event_pid: gen_event_pid) }
  end

  @doc false
  def websocket_handle({ :text, event }, _conn_state, state) do
    event = JSEX.decode!(event)
    handle_event(event["event"], event, state)
  end

  @doc false
  def websocket_info({ :subscribe, channel }, _conn_state, state) do
    event = PusherEvent.subscribe(channel)
    { :reply, { :text, event }, state }
  end
  def websocket_info({ :unsubscribe, channel }, _conn_state, state) do
    event = PusherEvent.unsubscribe(channel)
    { :reply, { :text, event }, state }
  end
  def websocket_info(:stop, _conn_state, _state) do
    { :close, "Normal shutdown", nil }
  end
  def websocket_info(info, _conn_state, state) do
    Lager.info "info: #{inspect info}"
    { :ok, state }
  end

  @doc false
  def websocket_terminate({ :close, code, payload }, _conn_state, _state) do
    Lager.info "websocket close with code #{code} and payload #{payload}."
    :ok
  end
  def websocket_terminate(reason, _conn_state, _state) do
    Lager.info "Terminated: #{inspect reason}"
    :ok
  end

  @doc false
  defp handle_event("pusher:connection_established", event, state) do
    socket_id = event["data"]["socket_id"]
    Lager.info "Connection established on socket id: #{socket_id}"
    { :ok, state.update(socket_id: socket_id) }
  end
  defp handle_event("pusher_internal:subscription_succeeded", _event, state) do
    { :ok, state }
  end
  defp handle_event(event_name, event, WSHandlerInfo[gen_event_pid: gen_event_pid] = state) do
    :gen_event.notify(gen_event_pid, { event["channel"], event_name, event["data"] })
    { :ok, state }
  end
end