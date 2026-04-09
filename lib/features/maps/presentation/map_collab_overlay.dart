import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/realtime/map_collab_models.dart';
import '../../../core/realtime/member_audio_prefs.dart';
import '../../../core/realtime/ptt_queue.dart';
import '../../../core/realtime/realtime_ptt_service.dart';

String _resolveRoomOwnerId(PttQueueState st, String sessionOwnerFallback) {
  for (final e in st.members.entries) {
    if (e.value.role == GroupRole.owner) return e.key;
  }
  return sessionOwnerFallback;
}

/// Harita sağında: baloncuk açılınca konuşma / oda ayarları, üyeler ve sohbet.
class MapCollabHubOverlay extends StatefulWidget {
  const MapCollabHubOverlay({
    super.key,
    required this.service,
    required this.currentUserId,
    this.inviteRoomNumber,
    this.onReportTarget,
    required this.ownerSharesLiveLocation,
    required this.onOwnerSharesLiveChanged,
    required this.followRoomOwnerLocation,
    required this.onFollowRoomOwnerChanged,
    required this.memberSharesLocation,
    required this.onMemberSharesLocationChanged,
    required this.onCreateRoom,
    required this.onJoinRoom,
    this.onRenewRoomInvite,
    required this.onShareInvite,
    this.onOpenMemberManagementSheet,
    required this.onSelfRename,
    required this.onPttTalk,
    required this.onPttRelease,
    this.onForceNextSpeaker,
  });

  final RealtimePttService service;
  final String currentUserId;

  /// Davet metninde kullanılan okunabilir oda numarası (varsa).
  final String? inviteRoomNumber;

  /// Harita hedef bildirimi (koordinat sayfası).
  final VoidCallback? onReportTarget;

  final bool ownerSharesLiveLocation;
  final ValueChanged<bool> onOwnerSharesLiveChanged;

  /// Kurucunun paylaştığı canlı konumu haritada takip et (üyeler için).
  final bool followRoomOwnerLocation;
  final ValueChanged<bool> onFollowRoomOwnerChanged;

  final bool memberSharesLocation;
  final ValueChanged<bool> onMemberSharesLocationChanged;

  final VoidCallback onCreateRoom;
  final VoidCallback onJoinRoom;
  final VoidCallback? onRenewRoomInvite;
  final VoidCallback onShareInvite;

  /// Tam PTT / üye moderasyonu (harita detay sheet).
  final VoidCallback? onOpenMemberManagementSheet;

  final VoidCallback onSelfRename;
  final VoidCallback onPttTalk;
  final VoidCallback onPttRelease;
  final VoidCallback? onForceNextSpeaker;

  @override
  State<MapCollabHubOverlay> createState() => _MapCollabHubOverlayState();
}

class _MapCollabHubOverlayState extends State<MapCollabHubOverlay> {
  bool _expanded = false;

  /// 0 = Oda & konuşma, 1 = Üyeler, 2 = Sohbet
  int _tab = 0;

  final _chatInput = TextEditingController();
  final _scroll = ScrollController();
  final List<MapCollabChatMessage> _chatLines = [];
  StreamSubscription<MapCollabChatMessage>? _chatSub;

  @override
  void initState() {
    super.initState();
    _chatSub = widget.service.chatMessages.listen(_onChat);
  }

  @override
  void didUpdateWidget(covariant MapCollabHubOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      _chatSub?.cancel();
      _chatSub = widget.service.chatMessages.listen(_onChat);
      setState(() => _chatLines.clear());
    }
  }

  void _onChat(MapCollabChatMessage m) {
    if (!mounted) return;
    setState(() {
      _chatLines.add(m);
      if (_chatLines.length > 120) {
        _chatLines.removeRange(0, _chatLines.length - 120);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _chatInput.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _sendChat() {
    final t = _chatInput.text;
    if (t.trim().isEmpty) return;
    widget.service.sendChatMessage(t);
    _chatInput.clear();
  }

  void _expandToOdaTab() {
    setState(() {
      _expanded = true;
      _tab = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    final cardW = math.min(320.0, mq.width * 0.92);

    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.service.stateListenable,
        widget.service.memberAudioPrefsListenable,
      ]),
      builder: (context, _) {
        final st = widget.service.state;
        final audioMap = widget.service.memberAudioPrefsMap;
        final n = st.members.length;
        final roomOwnerId = _resolveRoomOwnerId(st, widget.service.session.ownerUserId);
        if (!_expanded) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _expandToOdaTab,
              borderRadius: BorderRadius.circular(28),
              child: Ink(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.settings_voice, color: Colors.white, size: 26),
                        if (n > 1)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: CircleAvatar(
                              radius: 9,
                              backgroundColor: Colors.deepOrange,
                              child: Text(
                                '$n',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      n <= 1 ? 'Konuşma' : '$n kişi',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Material(
          color: Colors.transparent,
          child: Container(
            width: cardW,
            constraints: BoxConstraints(
              maxHeight: mq.height * 0.48,
              minHeight: 200,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
              boxShadow: const [
                BoxShadow(blurRadius: 12, color: Colors.black54, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CollabPanelHeader(
                  sessionId: widget.service.session.sessionId,
                  inviteRoomNumber: widget.inviteRoomNumber,
                  onShareInvite: widget.onShareInvite,
                  onCollapse: () => setState(() => _expanded = false),
                  onOpenMemberSheet: widget.onOpenMemberManagementSheet,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Oda'), icon: Icon(Icons.tune, size: 17)),
                      ButtonSegment(value: 1, label: Text('Üyeler'), icon: Icon(Icons.people_outline, size: 17)),
                      ButtonSegment(value: 2, label: Text('Sohbet'), icon: Icon(Icons.chat_bubble_outline, size: 17)),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (s) => setState(() => _tab = s.first),
                  ),
                ),
                if (_tab == 0)
                  Flexible(
                    child: _RoomAndPttTab(
                      service: widget.service,
                      st: st,
                      roomOwnerUserId: roomOwnerId,
                      ownerSharesLiveLocation: widget.ownerSharesLiveLocation,
                      onOwnerSharesLiveChanged: widget.onOwnerSharesLiveChanged,
                      followRoomOwnerLocation: widget.followRoomOwnerLocation,
                      onFollowRoomOwnerChanged: widget.onFollowRoomOwnerChanged,
                      memberSharesLocation: widget.memberSharesLocation,
                      onMemberSharesLocationChanged: widget.onMemberSharesLocationChanged,
                      onCreateRoom: widget.onCreateRoom,
                      onJoinRoom: widget.onJoinRoom,
                      onRenewRoomInvite: widget.onRenewRoomInvite,
                      onShareInvite: widget.onShareInvite,
                      onReportTarget: widget.onReportTarget,
                      currentUserId: widget.currentUserId,
                      onSelfRename: widget.onSelfRename,
                      onPttTalk: widget.onPttTalk,
                      onPttRelease: widget.onPttRelease,
                      onForceNextSpeaker: widget.onForceNextSpeaker,
                    ),
                  )
                else if (_tab == 1)
                  Flexible(
                    child: _MembersTab(
                      st: st,
                      currentUserId: widget.currentUserId,
                      roomOwnerUserId: roomOwnerId,
                      audioMap: audioMap,
                    ),
                  )
                else
                  Flexible(
                    child: _ChatTab(
                      lines: _chatLines,
                      scroll: _scroll,
                      input: _chatInput,
                      onSend: _sendChat,
                      currentUserId: widget.currentUserId,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CollabPanelHeader extends StatelessWidget {
  const _CollabPanelHeader({
    required this.sessionId,
    this.inviteRoomNumber,
    required this.onShareInvite,
    required this.onCollapse,
    this.onOpenMemberSheet,
  });

  final String sessionId;
  final String? inviteRoomNumber;
  final VoidCallback onShareInvite;
  final VoidCallback onCollapse;
  final VoidCallback? onOpenMemberSheet;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Konuşma ve oda',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  inviteRoomNumber != null && inviteRoomNumber!.isNotEmpty
                      ? 'Oda ismi: $inviteRoomNumber'
                      : 'Yerel / genel oturum',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Kimlik: $sessionId',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Davet paylaş',
            onPressed: onShareInvite,
            icon: const Icon(Icons.ios_share, color: Colors.white70, size: 20),
          ),
          if (onOpenMemberSheet != null)
            IconButton(
              tooltip: 'Detaylı PTT (menü)',
              onPressed: onOpenMemberSheet,
              icon: const Icon(Icons.menu_book_outlined, color: Colors.white70, size: 22),
            ),
          IconButton(
            tooltip: 'Küçült',
            onPressed: onCollapse,
            icon: const Icon(Icons.unfold_less, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _RoomAndPttTab extends StatelessWidget {
  const _RoomAndPttTab({
    required this.service,
    required this.st,
    required this.roomOwnerUserId,
    required this.ownerSharesLiveLocation,
    required this.onOwnerSharesLiveChanged,
    required this.followRoomOwnerLocation,
    required this.onFollowRoomOwnerChanged,
    required this.memberSharesLocation,
    required this.onMemberSharesLocationChanged,
    required this.onCreateRoom,
    required this.onJoinRoom,
    this.onRenewRoomInvite,
    required this.onShareInvite,
    this.onReportTarget,
    required this.currentUserId,
    required this.onSelfRename,
    required this.onPttTalk,
    required this.onPttRelease,
    this.onForceNextSpeaker,
  });

  final RealtimePttService service;
  final PttQueueState st;
  final String roomOwnerUserId;
  final bool ownerSharesLiveLocation;
  final ValueChanged<bool> onOwnerSharesLiveChanged;
  final bool followRoomOwnerLocation;
  final ValueChanged<bool> onFollowRoomOwnerChanged;
  final bool memberSharesLocation;
  final ValueChanged<bool> onMemberSharesLocationChanged;
  final VoidCallback onCreateRoom;
  final VoidCallback onJoinRoom;
  final VoidCallback? onRenewRoomInvite;
  final VoidCallback onShareInvite;
  final VoidCallback? onReportTarget;
  final String currentUserId;
  final VoidCallback onSelfRename;
  final VoidCallback onPttTalk;
  final VoidCallback onPttRelease;
  final VoidCallback? onForceNextSpeaker;

  @override
  Widget build(BuildContext context) {
    final ownerName = st.members[roomOwnerUserId]?.displayName ?? 'Kurucu';
    final canForceNext = st.members[currentUserId]?.role == GroupRole.owner;
    final isRoomOwner = st.members[currentUserId]?.role == GroupRole.owner;
    final localAud = service.memberAudioPrefsFor(currentUserId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      children: [
        Text(
          'Oda',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            FilledButton.tonal(
              onPressed: onCreateRoom,
              child: const Text('Oluştur'),
            ),
            OutlinedButton(
              onPressed: onJoinRoom,
              child: const Text('Katıl'),
            ),
            OutlinedButton(
              onPressed: onShareInvite,
              child: const Text('Davet'),
            ),
          ],
        ),
        if (onRenewRoomInvite != null &&
            isRoomOwner &&
            !service.session.sessionId.startsWith('yerel-')) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRenewRoomInvite,
            icon: const Icon(Icons.vpn_key_outlined, size: 18),
            label: const Text('Davet bilgisini yenile'),
          ),
          Text(
            'Yeni oda ismi/şifre; eski mesaj bağlantısı çalışmaz.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.42), fontSize: 10),
          ),
        ],
        if (onReportTarget != null &&
            !service.session.sessionId.startsWith('yerel-')) ...[
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onReportTarget,
            icon: const Icon(Icons.crisis_alert_outlined, size: 20),
            label: const Text('Hedef bildir'),
          ),
          Text(
            'Koordinat sayfası açılır (UTM, MGRS, DD…). Bildirenin konumundan mesafe ve istikamet eklenir. '
            'Diğer cihazlar için canlı iletimde sunucunun targetReport olayını iletmesi gerekir.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (isRoomOwner) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Konumumu canlı paylaş'),
            subtitle: const Text('Kurucu olarak ~5 sn aralıkla konum gönderirsiniz.'),
            value: ownerSharesLiveLocation,
            onChanged: onOwnerSharesLiveChanged,
          ),
        ] else ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('$ownerName konumunu takip et'),
            subtitle: const Text(
              'Kurucu paylaşıyorsa harita otomatik kayar. İstediğinizde kapatabilirsiniz.',
            ),
            value: followRoomOwnerLocation,
            onChanged: onFollowRoomOwnerChanged,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Konumumu haritada paylaş'),
            subtitle: const Text('Üye olarak odadakiler anlık konumunuzu görür (~5 sn).'),
            value: memberSharesLocation,
            onChanged: onMemberSharesLocationChanged,
          ),
        ],
        const Divider(height: 22),
        Text(
          'Ses',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Giriş modu (gerçek ses işi bağlanınca etkinleşir)',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10),
        ),
        const SizedBox(height: 6),
        SegmentedButton<PttInputMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment<PttInputMode>(
              value: PttInputMode.voiceActivated,
              tooltip: 'Ses eşiği — algılanınca konuş',
              label: Text('Sesli'),
            ),
            ButtonSegment<PttInputMode>(
              value: PttInputMode.pushToTalk,
              label: Text('Bas-Konuş'),
            ),
            ButtonSegment<PttInputMode>(
              value: PttInputMode.alwaysOn,
              tooltip: 'Sürekli mikrofon açık',
              label: Text('Açık mic'),
            ),
          ],
          selected: {localAud.inputMode},
          onSelectionChanged: (s) {
            service.publishMemberAudioPrefs(localAud.copyWith(inputMode: s.first));
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mikrofonu sessize al'),
          subtitle: const Text('Konuş düğmesi devre dışı kalır.'),
          value: localAud.micSelfMuted,
          onChanged: (v) {
            service.publishMemberAudioPrefs(localAud.copyWith(micSelfMuted: v));
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Odayı dinle (hoparlör)'),
          subtitle: const Text(
            'Kapalıysa kulaklık/hoparlör kapalı varsayılır; «Üyeler» sekmesinde görünür.',
          ),
          value: localAud.speakerOn,
          onChanged: (v) {
            service.publishMemberAudioPrefs(localAud.copyWith(speakerOn: v));
          },
        ),
        const Divider(height: 22),
        Text(
          'Grup telsizi',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: onSelfRename,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Adım'),
            ),
            FilledButton.icon(
              onPressed: onPttTalk,
              icon: const Icon(Icons.mic, size: 18),
              label: const Text('Konuş'),
            ),
            OutlinedButton.icon(
              onPressed: onPttRelease,
              icon: const Icon(Icons.mic_off, size: 18),
              label: const Text('Bırak'),
            ),
            if (canForceNext && onForceNextSpeaker != null)
              OutlinedButton.icon(
                onPressed: onForceNextSpeaker,
                icon: const Icon(Icons.skip_next, size: 18),
                label: const Text('Sıradaki'),
              ),
          ],
        ),
      ],
    );
  }
}

class _MembersTab extends StatelessWidget {
  const _MembersTab({
    required this.st,
    required this.currentUserId,
    required this.roomOwnerUserId,
    required this.audioMap,
  });

  final PttQueueState st;
  final String currentUserId;
  final String roomOwnerUserId;
  final Map<String, MemberAudioPrefs> audioMap;

  @override
  Widget build(BuildContext context) {
    final members = st.members.values.toList()
      ..sort((a, b) {
        if (a.userId == roomOwnerUserId) return -1;
        if (b.userId == roomOwnerUserId) return 1;
        if (a.userId == currentUserId) return -1;
        if (b.userId == currentUserId) return 1;
        return a.displayName.compareTo(b.displayName);
      });
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      itemCount: members.length,
      itemBuilder: (context, i) {
        final m = members[i];
        final isSelf = m.userId == currentUserId;
        final isOwnerRow = m.userId == roomOwnerUserId;
        final speaking = st.currentSpeakerId == m.userId;
        final queued = st.queuedUserIds.contains(m.userId);
        final roleTr = isOwnerRow ? ' · oda kurucusu' : '';
        final aud = audioMap[m.userId] ?? const MemberAudioPrefs();
        final modeTr = switch (aud.inputMode) {
          PttInputMode.voiceActivated => 'ses algılama',
          PttInputMode.pushToTalk => 'bas-konuş',
          PttInputMode.alwaysOn => 'açık mic',
        };
        final listenTr = aud.speakerOn ? '' : ' · kulaklık/hoparlör kapalı';
        final selfMuteTr = aud.micSelfMuted ? ' · mic sessiz' : '';
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelf ? Icons.person : Icons.person_outline,
                color: speaking ? Colors.lightGreenAccent : Colors.white70,
                size: 22,
              ),
              if (!aud.speakerOn)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Icon(Icons.headset_off, color: Colors.orange.shade300, size: 18),
                ),
            ],
          ),
          title: Text(
            '${m.displayName}${isSelf ? ' (sen)' : ''}',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          subtitle: Text(
            '$modeTr · ${m.role.name}${m.muted ? ' · (mod) susturuldu' : ''}'
            '$selfMuteTr'
            '${speaking ? ' · konuşuyor' : ''}'
            '${queued ? ' · sırada' : ''}'
            '$listenTr'
            '$roleTr',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
          ),
        );
      },
    );
  }
}

class _ChatTab extends StatelessWidget {
  const _ChatTab({
    required this.lines,
    required this.scroll,
    required this.input,
    required this.onSend,
    required this.currentUserId,
  });

  final List<MapCollabChatMessage> lines;
  final ScrollController scroll;
  final TextEditingController input;
  final VoidCallback onSend;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            itemCount: lines.length,
            itemBuilder: (context, i) {
              final m = lines[i];
              final mine = m.userId == currentUserId;
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  constraints: const BoxConstraints(maxWidth: 260),
                  decoration: BoxDecoration(
                    color: mine
                        ? Colors.green.shade900.withValues(alpha: 0.55)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mine ? 'Sen' : m.displayName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.text,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: input,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Mesaj…',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  maxLines: 2,
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: onSend,
                icon: const Icon(Icons.send, size: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
