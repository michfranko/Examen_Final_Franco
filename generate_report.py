from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
import os

EVIDENCE_DIR = 'evidence'
OUT_PDF = 'evidence_report.pdf'

def draw_text(c, text, x, y, leading=14):
    for line in text.splitlines():
        c.drawString(x, y, line)
        y -= leading
    return y

def main():
    c = canvas.Canvas(OUT_PDF, pagesize=A4)
    width, height = A4
    y = height - 40
    c.setFont('Helvetica-Bold', 14)
    c.drawString(40, y, 'Evidencias del despliegue Kubernetes')
    y -= 30
    c.setFont('Helvetica', 10)

    if not os.path.isdir(EVIDENCE_DIR):
        c.drawString(40, y, f'No se encontró el directorio {EVIDENCE_DIR}. Ejecute los scripts de recolección primero.')
        c.save()
        print('PDF generado:', OUT_PDF)
        return

    files = sorted([f for f in os.listdir(EVIDENCE_DIR) if f.endswith('.txt')])
    for fname in files:
        if y < 80:
            c.showPage()
            y = height - 40
            c.setFont('Helvetica', 10)
        c.setFont('Helvetica-Bold', 12)
        c.drawString(40, y, fname)
        y -= 20
        c.setFont('Helvetica', 9)
        with open(os.path.join(EVIDENCE_DIR, fname), 'r', encoding='utf-8', errors='replace') as fh:
            text = fh.read()
        y = draw_text(c, text, 40, y, leading=12)
        y -= 20

    c.save()
    print('PDF generado:', OUT_PDF)

if __name__ == '__main__':
    main()
