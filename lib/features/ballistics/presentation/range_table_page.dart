import 'package:flutter/material.dart';

import '../../../core/ballistics/ballistics_engine.dart';
import '../../../core/ballistics/ballistics_export.dart';
import 'strelock_ballistics_ui.dart';

/// Dikey / yatay düzeltme sütunları için gösterim birimi.
enum RangeCorrectionDisplay { mil, moa, click, cm }

class RangeTablePage extends StatefulWidget {
  const RangeTablePage({
    super.key,
    required this.rows,
    required this.clickUnitShort,
  });

  final List<RangeTableRow> rows;
  final String clickUnitShort;

  @override
  State<RangeTablePage> createState() => _RangeTablePageState();
}

class _RangeTablePageState extends State<RangeTablePage> {
  bool _showVelocity = true;
  bool _showEnergy = false;
  bool _showTof = true;
  bool _showDropCmCol = false;
  bool _showLeadLat = true;
  RangeCorrectionDisplay _elevUnit = RangeCorrectionDisplay.mil;
  RangeCorrectionDisplay _windUnit = RangeCorrectionDisplay.mil;
  bool _settingsOpen = true;

  String _fmtElev(RangeTableRow r) {
    switch (_elevUnit) {
      case RangeCorrectionDisplay.mil:
        return r.dropMil.toStringAsFixed(2);
      case RangeCorrectionDisplay.moa:
        return r.dropMoa.toStringAsFixed(2);
      case RangeCorrectionDisplay.click:
        return r.elevClicks.toStringAsFixed(1);
      case RangeCorrectionDisplay.cm:
        return r.dropCmApprox.toStringAsFixed(0);
    }
  }

  String _fmtWind(RangeTableRow r) {
    switch (_windUnit) {
      case RangeCorrectionDisplay.mil:
        return r.windMil.toStringAsFixed(2);
      case RangeCorrectionDisplay.moa:
        return r.windMoa.toStringAsFixed(2);
      case RangeCorrectionDisplay.click:
        return r.windClicks.toStringAsFixed(1);
      case RangeCorrectionDisplay.cm:
        return r.windCmApprox.toStringAsFixed(0);
    }
  }

  /// Öncü ve latΣ; birim seçimi yatay (Wind) sütunuyla paylaşılır.
  String _fmtLead(RangeTableRow r) {
    switch (_windUnit) {
      case RangeCorrectionDisplay.mil:
        return r.leadMil.toStringAsFixed(2);
      case RangeCorrectionDisplay.moa:
        return r.leadMoa.toStringAsFixed(2);
      case RangeCorrectionDisplay.click:
        return r.leadClicks.toStringAsFixed(1);
      case RangeCorrectionDisplay.cm:
        return r.leadCmApprox.toStringAsFixed(0);
    }
  }

  String _fmtLatSum(RangeTableRow r) {
    switch (_windUnit) {
      case RangeCorrectionDisplay.mil:
        return r.combinedLateralMil.toStringAsFixed(2);
      case RangeCorrectionDisplay.moa:
        return r.combinedLateralMoa.toStringAsFixed(2);
      case RangeCorrectionDisplay.click:
        return r.combinedLateralClicks.toStringAsFixed(1);
      case RangeCorrectionDisplay.cm:
        return r.combinedLateralCmApprox.toStringAsFixed(0);
    }
  }

  String _lateralBlockLegend() {
    return switch (_windUnit) {
      RangeCorrectionDisplay.mil => 'mil',
      RangeCorrectionDisplay.moa => 'MOA',
      RangeCorrectionDisplay.click => 'klik',
      RangeCorrectionDisplay.cm => 'cm',
    };
  }

  String _elevHeader() {
    return switch (_elevUnit) {
      RangeCorrectionDisplay.mil => 'Dikey\nmil',
      RangeCorrectionDisplay.moa => 'Dikey\nMOA',
      RangeCorrectionDisplay.click => 'Dikey\nklik',
      RangeCorrectionDisplay.cm => 'Dikey\ncm',
    };
  }

  String _windHeader() {
    return switch (_windUnit) {
      RangeCorrectionDisplay.mil => 'Yanal\nmil',
      RangeCorrectionDisplay.moa => 'Yanal\nMOA',
      RangeCorrectionDisplay.click => 'Yanal\nklik',
      RangeCorrectionDisplay.cm => 'Yanal\ncm',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StreLockBalColors.scaffold,
      appBar: AppBar(
        backgroundColor: StreLockBalColors.scaffold,
        foregroundColor: StreLockBalColors.label,
        elevation: 0,
        title: Text(
          'Menzil tablosu',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: StreLockBalColors.headerOrange,
                fontWeight: FontWeight.w800,
              ),
        ),
        actions: [
          IconButton(
            tooltip: 'CSV',
            onPressed: widget.rows.isEmpty
                ? null
                : () async {
                    final csv = rangeTableToCsv(widget.rows);
                    await shareCsvText(csv, filename: 'blue_viper_range.csv');
                  },
            icon: const Icon(Icons.ios_share_outlined),
          ),
          IconButton(
            tooltip: 'Excel (xlsx)',
            onPressed: widget.rows.isEmpty
                ? null
                : () async {
                    await shareRangeTableXlsx(
                      rows: widget.rows,
                      filename: 'blue_viper_range.xlsx',
                    );
                  },
            icon: const Icon(Icons.table_chart_outlined),
          ),
          IconButton(
            tooltip: 'PDF',
            onPressed: widget.rows.isEmpty
                ? null
                : () async {
                    await shareRangeTablePdf(
                      rows: widget.rows,
                      title: 'Menzil tablosu',
                      filename: 'blue_viper_range.pdf',
                    );
                  },
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: Colors.black.withValues(alpha: 0.25),
            child: ExpansionTile(
              initiallyExpanded: _settingsOpen,
              onExpansionChanged: (v) => setState(() => _settingsOpen = v),
              title: Text(
                'Sütunlar ve birimler',
                style: streLockSectionStyle(context).copyWith(fontSize: 14),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    children: [
                      StreLockToggleRow(
                        label: 'Çarpma hızı (m/s)',
                        value: _showVelocity,
                        onChanged: (v) => setState(() => _showVelocity = v),
                      ),
                      StreLockToggleRow(
                        label: 'Enerji (J, gr bilgisi varsa)',
                        value: _showEnergy,
                        onChanged: (v) => setState(() => _showEnergy = v),
                      ),
                      StreLockToggleRow(
                        label: 'Uçuş süresi (ms)',
                        value: _showTof,
                        onChanged: (v) => setState(() => _showTof = v),
                      ),
                      StreLockToggleRow(
                        label: 'Düşüş cm (fiziksel sapma)',
                        value: _showDropCmCol,
                        onChanged: (v) => setState(() => _showDropCmCol = v),
                      ),
                      StreLockToggleRow(
                        label: 'Öncü + yatay toplam (mil)',
                        value: _showLeadLat,
                        onChanged: (v) => setState(() => _showLeadLat = v),
                      ),
                      StreLockDropdown<RangeCorrectionDisplay>(
                        label: 'Dikey sütun',
                        value: _elevUnit,
                        items: const [
                          DropdownMenuItem(value: RangeCorrectionDisplay.mil, child: Text('MRAD')),
                          DropdownMenuItem(value: RangeCorrectionDisplay.moa, child: Text('MOA')),
                          DropdownMenuItem(value: RangeCorrectionDisplay.click, child: Text('Klik')),
                          DropdownMenuItem(value: RangeCorrectionDisplay.cm, child: Text('cm')),
                        ],
                        onChanged: (v) => setState(() => _elevUnit = v ?? _elevUnit),
                      ),
                      StreLockDropdown<RangeCorrectionDisplay>(
                        label: 'Yanal · öncü · latΣ',
                        value: _windUnit,
                        items: const [
                          DropdownMenuItem(value: RangeCorrectionDisplay.mil, child: Text('MRAD')),
                          DropdownMenuItem(value: RangeCorrectionDisplay.moa, child: Text('MOA')),
                          DropdownMenuItem(value: RangeCorrectionDisplay.click, child: Text('Klik')),
                          DropdownMenuItem(value: RangeCorrectionDisplay.cm, child: Text('cm')),
                        ],
                        onChanged: (v) => setState(() => _windUnit = v ?? _windUnit),
                      ),
                      Text(
                        'Klik: ${widget.clickUnitShort}',
                        style: streLockLabelStyle(context).copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.rows.isEmpty
                ? Center(
                    child: Text('Satır yok', style: streLockLabelStyle(context)),
                  )
                : ListView.builder(
                    itemCount: widget.rows.length,
                    itemBuilder: (ctx, i) {
                      final r = widget.rows[i];
                      final stripe = i.isEven
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.03);
                      final cells = <Widget>[
                        _cell('${r.rangeMeters}', bold: true),
                        _cell(_fmtElev(r)),
                        _cell(_fmtWind(r)),
                      ];
                      if (_showDropCmCol) {
                        cells.add(_cell(r.dropCmApprox.toStringAsFixed(0)));
                      }
                      if (_showLeadLat) {
                        cells.add(_cell(_fmtLead(r)));
                        cells.add(_cell(_fmtLatSum(r)));
                      }
                      if (_showTof) {
                        cells.add(_cell(r.tofMs.toStringAsFixed(0)));
                      }
                      if (_showVelocity) {
                        cells.add(_cell(r.impactVelocityMps.toStringAsFixed(0)));
                      }
                      if (_showEnergy) {
                        cells.add(_cell(r.impactEnergyJoules != null
                            ? r.impactEnergyJoules!.toStringAsFixed(0)
                            : '—'));
                      }
                      return Material(
                        color: stripe,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          child: Row(
                            children: [
                              for (var j = 0; j < cells.length; j++)
                                Expanded(
                                  flex: j == 0 ? 2 : 3,
                                  child: cells[j],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          _headerLegend(context),
        ],
      ),
    );
  }

  Widget _cell(String text, {bool bold = false}) {
    return Text(
      text,
      textAlign: TextAlign.end,
      style: TextStyle(
        color: StreLockBalColors.label,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        fontSize: 13,
      ),
    );
  }

  Widget _headerLegend(BuildContext context) {
    final parts = <String>[
      'm',
      _elevHeader().replaceAll('\n', ' '),
      _windHeader().replaceAll('\n', ' '),
    ];
    if (_showDropCmCol) parts.add('düş cm');
    if (_showLeadLat) {
      final u = _lateralBlockLegend();
      parts.add('öncü $u');
      parts.add('latΣ $u');
    }
    if (_showTof) parts.add('TOF');
    if (_showVelocity) parts.add('V');
    if (_showEnergy) parts.add('J');
    return Material(
      color: StreLockBalColors.footerBar,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Text(
            parts.join(' · '),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
