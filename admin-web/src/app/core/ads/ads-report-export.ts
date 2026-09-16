/** Exportaciones del informe de patrocinios (Excel / Word) sin dependencias extra. */

export interface AdsReportExportRow {
  sponsorName: string;
  zoneLabel: string;
  detail: string;
  active: boolean | null;
  impressions: number;
  clicks: number;
  ctr: number;
}

export interface AdsReportExportZone {
  label: string;
  activePieces: number;
  totalPieces: number;
  impressions: number;
  clicks: number;
  ctr: number;
}

export interface AdsReportExportInput {
  periodLabel: string;
  generatedAt: Date;
  totals: {
    impressions: number;
    clicks: number;
    ctr: number;
    companies: number;
    zones: number;
    pieces: number;
  };
  zones: AdsReportExportZone[];
  rows: AdsReportExportRow[];
  logoDataUrl?: string | null;
}

function escapeXml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function formatInt(value: number): string {
  return new Intl.NumberFormat('es-ES').format(value);
}

function formatCtr(value: number): string {
  return `${value.toLocaleString('es-ES', {
    minimumFractionDigits: value % 1 === 0 ? 0 : 1,
    maximumFractionDigits: 2,
  })}%`;
}

function statusLabel(active: boolean | null): string {
  if (active === true) return 'Activa';
  if (active === false) return 'Pausada';
  return '—';
}

function stamp(date: Date): string {
  return date.toLocaleString('es-ES', {
    dateStyle: 'long',
    timeStyle: 'short',
  });
}

function fileStamp(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function downloadBlob(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export async function fetchBrandLogoDataUrl(
  path = '/logo-mark.png',
): Promise<string | null> {
  try {
    const res = await fetch(path);
    if (!res.ok) return null;
    const blob = await res.blob();
    return await new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(String(reader.result));
      reader.onerror = () => reject(reader.error);
      reader.readAsDataURL(blob);
    });
  } catch {
    return null;
  }
}

/** Excel compatible (.xls XML) — se abre en Excel / LibreOffice. */
export function downloadAdsReportExcel(input: AdsReportExportInput): void {
  const rowsXml = input.rows
    .map(
      (row) => `
    <Row>
      <Cell><Data ss:Type="String">${escapeXml(row.sponsorName)}</Data></Cell>
      <Cell><Data ss:Type="String">${escapeXml(row.zoneLabel)}</Data></Cell>
      <Cell><Data ss:Type="String">${escapeXml(row.detail || '—')}</Data></Cell>
      <Cell><Data ss:Type="String">${escapeXml(statusLabel(row.active))}</Data></Cell>
      <Cell><Data ss:Type="Number">${row.impressions}</Data></Cell>
      <Cell><Data ss:Type="Number">${row.clicks}</Data></Cell>
      <Cell><Data ss:Type="Number">${row.ctr}</Data></Cell>
    </Row>`,
    )
    .join('');

  const zonesXml = input.zones
    .map(
      (zone) => `
    <Row>
      <Cell><Data ss:Type="String">${escapeXml(zone.label)}</Data></Cell>
      <Cell><Data ss:Type="Number">${zone.activePieces}</Data></Cell>
      <Cell><Data ss:Type="Number">${zone.totalPieces}</Data></Cell>
      <Cell><Data ss:Type="Number">${zone.impressions}</Data></Cell>
      <Cell><Data ss:Type="Number">${zone.clicks}</Data></Cell>
      <Cell><Data ss:Type="Number">${zone.ctr}</Data></Cell>
    </Row>`,
    )
    .join('');

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<?mso-application progid="Excel.Sheet"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:x="urn:schemas-microsoft-com:office:excel"
 xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:html="http://www.w3.org/TR/REC-html40">
 <Styles>
  <Style ss:ID="Header">
   <Font ss:Bold="1"/>
   <Interior ss:Color="#F5EFE8" ss:Pattern="Solid"/>
  </Style>
  <Style ss:ID="Title">
   <Font ss:Bold="1" ss:Size="14"/>
  </Style>
 </Styles>
 <Worksheet ss:Name="Resumen">
  <Table>
   <Row><Cell ss:StyleID="Title"><Data ss:Type="String">Informe de patrocinios · Círculo Cofrade</Data></Cell></Row>
   <Row><Cell><Data ss:Type="String">Periodo: ${escapeXml(input.periodLabel)}</Data></Cell></Row>
   <Row><Cell><Data ss:Type="String">Generado: ${escapeXml(stamp(input.generatedAt))}</Data></Cell></Row>
   <Row/>
   <Row><Cell ss:StyleID="Header"><Data ss:Type="String">Métrica</Data></Cell><Cell ss:StyleID="Header"><Data ss:Type="String">Valor</Data></Cell></Row>
   <Row><Cell><Data ss:Type="String">Vistas</Data></Cell><Cell><Data ss:Type="Number">${input.totals.impressions}</Data></Cell></Row>
   <Row><Cell><Data ss:Type="String">Clics</Data></Cell><Cell><Data ss:Type="Number">${input.totals.clicks}</Data></Cell></Row>
   <Row><Cell><Data ss:Type="String">CTR (%)</Data></Cell><Cell><Data ss:Type="Number">${input.totals.ctr}</Data></Cell></Row>
   <Row><Cell><Data ss:Type="String">Empresas</Data></Cell><Cell><Data ss:Type="Number">${input.totals.companies}</Data></Cell></Row>
   <Row><Cell><Data ss:Type="String">Zonas con datos</Data></Cell><Cell><Data ss:Type="Number">${input.totals.zones}</Data></Cell></Row>
   <Row><Cell><Data ss:Type="String">Piezas en tabla</Data></Cell><Cell><Data ss:Type="Number">${input.totals.pieces}</Data></Cell></Row>
  </Table>
 </Worksheet>
 <Worksheet ss:Name="Por zona">
  <Table>
   <Row>
    <Cell ss:StyleID="Header"><Data ss:Type="String">Zona</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">Activas</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">Total piezas</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">Vistas</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">Clics</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">CTR %</Data></Cell>
   </Row>
   ${zonesXml}
  </Table>
 </Worksheet>
 <Worksheet ss:Name="Detalle">
  <Table>
   <Row>
    <Cell ss:StyleID="Header"><Data ss:Type="String">Empresa</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">Zona</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">Detalle</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">Estado</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">Vistas</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">Clics</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">CTR %</Data></Cell>
   </Row>
   ${rowsXml}
  </Table>
 </Worksheet>
</Workbook>`;

  const blob = new Blob([xml], {
    type: 'application/vnd.ms-excel;charset=utf-8',
  });
  downloadBlob(
    blob,
    `circulo-cofrade-patrocinios-${fileStamp(input.generatedAt)}.xls`,
  );
}

/** Word legible (.doc HTML) con logo y explicación en lenguaje sencillo. */
export function downloadAdsReportWord(input: AdsReportExportInput): void {
  const logoHtml = input.logoDataUrl
    ? `<img class="logo" src="${input.logoDataUrl}" alt="Círculo Cofrade" />`
    : '';

  const zoneBlocks = input.zones
    .map((zone) => {
      const plain =
        zone.impressions === 0 && zone.clicks === 0
          ? 'En este periodo no hubo actividad registrada en esta zona.'
          : `Se mostró <strong>${formatInt(zone.impressions)}</strong> veces y la gente pulsó <strong>${formatInt(zone.clicks)}</strong> veces (CTR ${formatCtr(zone.ctr)}).`;
      return `
      <div class="zone">
        <h3>${escapeHtml(zone.label)}</h3>
        <p class="meta">${zone.activePieces} de ${zone.totalPieces} piezas activas ahora mismo.</p>
        <p>${plain}</p>
      </div>`;
    })
    .join('');

  const byZone = new Map<string, AdsReportExportRow[]>();
  for (const row of input.rows) {
    const list = byZone.get(row.zoneLabel) ?? [];
    list.push(row);
    byZone.set(row.zoneLabel, list);
  }

  const detailBlocks = [...byZone.entries()]
    .map(([zone, rows]) => {
      const items = rows
        .map((row) => {
          const activity =
            row.impressions === 0 && row.clicks === 0
              ? 'Sin vistas ni clics en el periodo.'
              : `${formatInt(row.impressions)} vistas · ${formatInt(row.clicks)} clics · CTR ${formatCtr(row.ctr)}`;
          return `
          <tr>
            <td><strong>${escapeHtml(row.sponsorName)}</strong><br/><span class="muted">${escapeHtml(row.detail || '—')}</span></td>
            <td>${escapeHtml(statusLabel(row.active))}</td>
            <td>${activity}</td>
          </tr>`;
        })
        .join('');
      return `
      <h3>${escapeHtml(zone)}</h3>
      <table>
        <thead>
          <tr><th>Empresa</th><th>Estado</th><th>Resultado</th></tr>
        </thead>
        <tbody>${items}</tbody>
      </table>`;
    })
    .join('');

  const html = `<!DOCTYPE html>
<html xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:w="urn:schemas-microsoft-com:office:word"
 xmlns="http://www.w3.org/TR/REC-html40" lang="es">
<head>
<meta charset="utf-8" />
<title>Informe de patrocinios · Círculo Cofrade</title>
<!--[if gte mso 9]>
<xml>
 <w:WordDocument>
  <w:View>Print</w:View>
 </w:WordDocument>
</xml>
<![endif]-->
<style>
  body { font-family: Calibri, Arial, sans-serif; color: #241f1c; line-height: 1.45; }
  .logo { height: 64px; width: auto; margin-bottom: 12px; }
  h1 { font-size: 22pt; color: #7a0814; margin: 0 0 6px; }
  h2 { font-size: 14pt; color: #7a0814; margin: 22px 0 8px; border-bottom: 1px solid #e7dfd6; padding-bottom: 4px; }
  h3 { font-size: 12pt; margin: 14px 0 4px; }
  .lead { color: #5c5652; margin: 0 0 14px; }
  .kpis td { padding: 6px 14px 6px 0; }
  .zone { margin: 0 0 12px; padding: 8px 0; }
  .meta { color: #6e6a67; font-size: 10pt; margin: 0 0 4px; }
  .muted { color: #6e6a67; font-size: 9.5pt; }
  table { border-collapse: collapse; width: 100%; margin: 8px 0 16px; }
  th, td { border: 1px solid #e7dfd6; padding: 8px; text-align: left; vertical-align: top; }
  th { background: #f5efe8; }
  .note { background: #faf7f2; border: 1px solid #e7dfd6; padding: 10px 12px; margin: 12px 0; }
</style>
</head>
<body>
  ${logoHtml}
  <h1>Informe de patrocinios</h1>
  <p class="lead">
    Círculo Cofrade · Periodo: <strong>${escapeHtml(input.periodLabel)}</strong><br/>
    Generado el ${escapeHtml(stamp(input.generatedAt))}
  </p>

  <div class="note">
    <strong>Cómo leer este informe (en cristiano)</strong>
    <ul>
      <li><strong>Vistas:</strong> cuántas veces se ha mostrado el anuncio a alguien en la app.</li>
      <li><strong>Clics:</strong> cuántas veces alguien ha pulsado para abrir el enlace de la empresa.</li>
      <li><strong>CTR:</strong> el porcentaje de vistas que acabaron en clic. Cuanto más alto, más interés genera esa pieza.</li>
      <li><strong>Zona:</strong> el sitio de la app donde sale (foros, calendario, buscar…).</li>
    </ul>
  </div>

  <h2>Resumen del periodo</h2>
  <table class="kpis">
    <tr><td>Vistas totales</td><td><strong>${formatInt(input.totals.impressions)}</strong></td></tr>
    <tr><td>Clics totales</td><td><strong>${formatInt(input.totals.clicks)}</strong></td></tr>
    <tr><td>CTR medio</td><td><strong>${formatCtr(input.totals.ctr)}</strong></td></tr>
    <tr><td>Empresas con datos</td><td><strong>${input.totals.companies}</strong></td></tr>
    <tr><td>Zonas con datos</td><td><strong>${input.totals.zones}</strong></td></tr>
  </table>

  <h2>Qué ha pasado en cada zona</h2>
  ${zoneBlocks || '<p>No hay zonas con piezas o actividad en este periodo.</p>'}

  <h2>Detalle por empresa y zona</h2>
  ${detailBlocks || '<p>No hay filas de detalle para este periodo.</p>'}

  <p class="muted">Documento generado automáticamente desde el Panel Junta de Círculo Cofrade.</p>
</body>
</html>`;

  const blob = new Blob(['\ufeff', html], {
    type: 'application/msword;charset=utf-8',
  });
  downloadBlob(
    blob,
    `circulo-cofrade-informe-patrocinios-${fileStamp(input.generatedAt)}.doc`,
  );
}
