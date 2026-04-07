/// User-facing or diagnosable notice from a [RealtimePttService] (e.g. server `error` frame).
class PttServiceNotice {
  final String? code;
  final String? message;
  final int? refSeq;

  const PttServiceNotice({
    this.code,
    this.message,
    this.refSeq,
  });
}
