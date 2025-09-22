typedef RpcInvoker = Future<dynamic> Function(
  String function, {
  Map<String, dynamic>? params,
});
