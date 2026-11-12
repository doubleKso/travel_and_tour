// Port of lib/features/ticket/presentation/pdf/eticket_pdf_service.dart
import UIKit
import CoreText

/// Builds a printable / shareable **A4** PDF of an e-ticket from a `TicketModel`.
///
/// Rendered with its own drawing code (no screen capture) so it lays out as a
/// proper full-width A4 document that paginates automatically. Real brand
/// assets are embedded: the white Epic World logo and the IATA
/// accredited-agent mark in the header, the carrier's own logo in the meta
/// band, and Material icons throughout (drawn from their SVG path data).
///
/// The Dart version uses the `pdf` package's widgets; this port draws the same
/// layout with Core Graphics / Core Text inside `UIGraphicsPDFRenderer`: the
/// same sections, measurements, Helvetica text sizes (with the `pdf` package's
/// Helvetica line box, ascent 0.718 + descent 0.207 of the size) and colours,
/// and the same `MultiPage` rule — a block that does not fit the rest of a page
/// starts the next one, under the repeated header and above the footer.
@MainActor
enum ETicketPdf {
    // Brand palette, mirrored from AppColors so the PDF matches the app.
    fileprivate static let green = pdfColor(0xFF4C8139)
    fileprivate static let greenDark = pdfColor(0xFF3A6429)
    fileprivate static let amber = pdfColor(0xFFE8A33D)
    fileprivate static let teal = pdfColor(0xFF0E8F8F)
    fileprivate static let ink = pdfColor(0xFF1C2417)
    fileprivate static let muted = pdfColor(0xFF6B7669)
    fileprivate static let tertiary = pdfColor(0xFF9AA394)
    fileprivate static let line = pdfColor(0xFFE4E8DF)
    fileprivate static let bgSoft = pdfColor(0xFFF6F8F4)
    fileprivate static let greenSurface = pdfColor(0xFFEAF2E5)
    fileprivate static let white = UIColor.white

    // Material icon path data (24×24 viewBox), drawn as vector paths so the PDF
    // shows real icons without depending on an embedded icon font.
    private static let icFlightTakeoff =
        "M2.5 19h19v2h-19v-2zm19.57-9.36c-.21-.8-1.04-1.28-1.84-1.06L14.92 10 8 3.57 6.09 4.08l4.15 7.19-4.98 1.33-1.97-1.54-1.45.39 2.59 4.49L21 11.49c.81-.23 1.28-1.05 1.07-1.85z"
    private static let icFlightLand =
        "M2.5 19h19v2h-19v-2zM9.68 13.27l4.35 1.16 5.31 1.42c.8.21 1.62-.26 1.84-1.06.21-.8-.26-1.62-1.06-1.84l-5.31-1.42-2.76-9.02L10.28 2v8.28L5.15 8.91l-.96-2.4-1.44-.39v5.16l1.44.39 5.49 1.6z"
    private static let icFlight =
        "M21 16v-2l-8-5V3.5c0-.83-.67-1.5-1.5-1.5S10 2.67 10 3.5V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5l8 2.5z"
    private static let icMail =
        "M20 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z"
    private static let icPeople =
        "M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"
    private static let icTicket =
        "M22 10V6c0-1.11-.9-2-2-2H4c-1.1 0-1.99.89-1.99 2v4c1.1 0 1.99.9 1.99 2s-.89 2-2 2v4c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2v-4c-1.1 0-2-.9-2-2s.9-2 2-2zm-9 7.5h-2v-2h2v2zm0-4.5h-2v-2h2v2zm0-4.5h-2v-2h2v2z"
    private static let icPassport =
        "M20 7h-4V5.5C16 4.12 14.88 3 13.5 3h-3C9.12 3 8 4.12 8 5.5V7H4c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-8-1.5c0-.28.22-.5.5-.5h3c.28 0 .5.22.5.5V7h-4V5.5zM12 13c.83 0 1.5.67 1.5 1.5S12.83 16 12 16s-1.5-.67-1.5-1.5S11.17 13 12 13zm4 5H8v-.75c0-1.33 2.67-2 4-2s4 .67 4 2V18z"
    private static let icPhone =
        "M6.62 10.79c1.44 2.83 3.76 5.14 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z"

    /// `PdfPageFormat.a4` in points.
    private static let a4 = CGSize(width: 595.27559, height: 841.88976)

    /// The 2-letter IATA carrier prefix used in the flight designator (e.g. 8M
    /// for Myanmar Airways, K7 for Air KBZ), derived from the operator name.
    private static func airlineCode(_ name: String) -> String {
        let n = name.lowercased()
        if n.contains("myanmar airways") || n.contains("mai") { return "8M" }
        if n.contains("kbz") { return "K7" }
        if n.contains("thanlwin") { return "N7" }
        if n.contains("national") || n.contains("mna") { return "UB" }
        if n.contains("golden") { return "Y5" }
        let letters = name.replacingOccurrences(of: "[^A-Za-z]", with: "", options: .regularExpression)
        if letters.isEmpty { return "EW" }
        return String(letters.prefix(letters.count >= 2 ? 2 : 1)).uppercased()
    }

    private static func flightNo(_ leg: TripOptionModel) -> String {
        "\(airlineCode(leg.operatorName))-\(abs(dartHashCode(leg.id)) % 900 + 100)"
    }

    /// How many traveller blocks the document has, preferring the travellers the
    /// customer actually entered over the recorded seat count.
    private static func passengerCount(_ t: TicketModel) -> Int {
        !t.passengers.isEmpty ? t.passengers.count : t.seatCount
    }

    /// The traveller at `index`, or nil on tickets issued before travellers
    /// were carried through (and on the mock catalogue).
    private static func passengerAt(_ t: TicketModel, _ index: Int) -> TicketPassenger? {
        index < t.passengers.count ? t.passengers[index] : nil
    }

    private static func passengerName(_ t: TicketModel, _ index: Int) -> String {
        let name = passengerAt(t, index)?.fullName ?? ""
        if !name.isEmpty { return name }
        // Without entered travellers there is only the booking contact to go on.
        // Anyone past the first stays unnamed rather than being given a made-up
        // one — this is the document they hand over at check-in.
        return index == 0 ? t.passengerName : "Traveller \(index + 1)"
    }

    /// A short, filesystem-safe name for the exported file.
    nonisolated static func fileName(_ t: TicketModel) -> String {
        "eticket_\(!t.bookingReference.isEmpty ? t.bookingReference : t.id).pdf"
    }

    /// Legacy screenshot path — wraps a captured PNG on a single A4 page. Kept for
    /// callers that still snapshot the widget; the download flow now prefers the
    /// native `build` for a true A4 layout.
    static func buildFromImage(_ pngBytes: Data) async -> Data {
        let image = UIImage(data: pngBytes)
        let margin: CGFloat = 20.0
        let page = CGRect(origin: .zero, size: a4)
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: UIGraphicsPDFRendererFormat())
        return renderer.pdfData { context in
            context.beginPage()
            bgSoft.setFill()
            UIRectFill(page)
            guard let image, image.size.width > 0, image.size.height > 0 else { return }
            let box = page.insetBy(dx: margin, dy: margin)
            let scale = min(box.width / image.size.width, box.height / image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: box.midX - size.width / 2, y: box.minY, width: size.width, height: size.height))
        }
    }

    /// The main A4 e-ticket. Flows across pages like `pw.MultiPage`.
    static func build(_ t: TicketModel) async -> Data {
        let assets = await Assets.load(t)
        let issued = DateFormat("dd MMM yyyy, h:mm a").format(t.issuedAt)
        let barcodeData = !t.bookingReference.isEmpty ? t.bookingReference : t.id
        let ref = !t.bookingReference.isEmpty ? t.bookingReference : t.id
        let hasReturn = t.inbound != nil

        var body: [PdfBlock] = [
            banner(assets),
            spacer(18),
            metaRow(issued, ref),
            spacer(14),
            dashDivider(),
            spacer(12),
            // Booked-by on the left, barcode filling the empty right side.
            bookedByRow(barcodeData),
            spacer(12),
            dashDivider(),
            spacer(16),
            flightLeg(t.outbound, assets.airlineLogo, isReturn: false),
        ]
        if hasReturn, let inbound = t.inbound {
            body += [
                spacer(16),
                dashDivider(),
                spacer(16),
                flightLeg(inbound, assets.airlineLogoReturn, isReturn: true),
            ]
        }
        body += [
            spacer(16),
            dashDivider(),
            spacer(16),
            passengersHeader(passengerCount(t)),
            spacer(12),
        ]
        for i in 0..<max(passengerCount(t), 0) {
            if i > 0 {
                body += [spacer(12), dashDivider(), spacer(12)]
            }
            body.append(passengerRow(t, i))
        }
        body += [spacer(16), dashDivider(), spacer(16)]
        body += importantInfo()

        return render(body, header: pageHeader(ref), footer: { page, count in pageFooter(page, count) })
    }

    // ── MultiPage ─────────────────────────────────────────────────────────────

    /// `pw.MultiPage(pageFormat: a4, margin: fromLTRB(28, 24, 28, 22))`.
    private static func render(
        _ body: [PdfBlock],
        header: PdfBlock,
        footer: (_ page: Int, _ count: Int) -> PdfBlock
    ) -> Data {
        let page = CGRect(origin: .zero, size: a4)
        let content = CGRect(x: 28, y: 24, width: page.width - 28 - 28, height: page.height - 24 - 22)
        let headerHeight = header.measure(content.width)
        let footerHeight = footer(1, 1).measure(content.width)
        let bodyTop = content.minY + headerHeight
        let bodyBottom = content.maxY - footerHeight

        // Pass 1: paginate. A block that does not fit the space left starts a
        // new page (unless the page is still empty).
        var pages: [[(block: PdfBlock, y: CGFloat, height: CGFloat)]] = [[]]
        var y = bodyTop
        for block in body {
            let height = block.measure(content.width)
            if y + height > bodyBottom + 0.01, let current = pages.last, !current.isEmpty {
                pages.append([])
                y = bodyTop
            }
            pages[pages.count - 1].append((block: block, y: y, height: height))
            y += height
        }

        // Pass 2: draw, now that the page count is known for the footer.
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: UIGraphicsPDFRendererFormat())
        return renderer.pdfData { context in
            for (index, placed) in pages.enumerated() {
                context.beginPage()
                header.paint(CGRect(x: content.minX, y: content.minY, width: content.width, height: headerHeight))
                for item in placed {
                    item.block.paint(CGRect(x: content.minX, y: item.y, width: content.width, height: item.height))
                }
                footer(index + 1, pages.count)
                    .paint(CGRect(x: content.minX, y: bodyBottom, width: content.width, height: footerHeight))
            }
        }
    }

    // ── Repeated per-page chrome ──────────────────────────────────────────────

    private static func pageHeader(_ ref: String) -> PdfBlock {
        PdfBlock { width, origin in
            let style = PdfStyle(size: 7.5, color: tertiary)
            let height = PdfText.height("Epic World · E-Ticket · \(ref)", style, width: width)
            if let origin {
                PdfText.draw("Epic World · E-Ticket · \(ref)", style, in: CGRect(x: origin.x, y: origin.y, width: width, height: height), align: .right)
            }
            return height + 6
        }
    }

    private static func pageFooter(_ page: Int, _ count: Int) -> PdfBlock {
        PdfBlock { width, origin in
            let style = PdfStyle(size: 7.5, color: tertiary)
            let left = "This is an electronically generated e-ticket."
            let right = "\(page) / \(count)"
            let height = PdfText.lineHeight(style)
            if let origin {
                let top = origin.y + 6
                PdfText.draw(left, style, in: CGRect(x: origin.x, y: top, width: width, height: height))
                PdfText.draw(right, style, in: CGRect(x: origin.x, y: top, width: width, height: height), align: .right)
            }
            return 6 + height
        }
    }

    // ── Green gradient banner (real Epic World + IATA logos) ──────────────────

    private static func banner(_ a: Assets) -> PdfBlock {
        PdfBlock { width, origin in
            let inner = width - 40
            let third = inner / 3

            let title = PdfStyle(size: 19, bold: true, color: white, letterSpacing: 1)
            let subtitle = PdfStyle(size: 8.5, color: white)
            let centerHeight = PdfText.height("E-Ticket", title, width: third)
                + 2
                + PdfText.height("This is not a boarding pass", subtitle, width: third)

            let leftSize = a.epicLogo.map { containSize($0.size, CGSize(width: third, height: 34)) }
            let rightSize = a.iataLogo.map { containSize($0.size, CGSize(width: third, height: 46)) }
            let leftHeight = leftSize?.height ?? brandTextHeight("EPIC WORLD", "Travel & Tours", width: third)
            let rightHeight = rightSize?.height ?? brandTextHeight("IATA", "ACCREDITED AGENT", width: third)
            let rowHeight = max(leftHeight, centerHeight, rightHeight)
            let height = 14 + rowHeight + 14

            if let origin {
                let rect = CGRect(x: origin.x, y: origin.y, width: width, height: height)
                drawGradient(
                    in: UIBezierPath(roundedRect: rect, cornerRadius: 12).cgPath,
                    rect: rect,
                    colors: [greenDark, green, amber],
                    stops: [0.0, 0.68, 1.0]
                )
                let rowTop = origin.y + 14
                let left = origin.x + 20

                // Epic World logo (white), left.
                if let logo = a.epicLogo, let size = leftSize {
                    logo.draw(in: CGRect(x: left, y: rowTop + (rowHeight - size.height) / 2, width: size.width, height: size.height))
                } else {
                    drawBrandText("EPIC WORLD", "Travel & Tours", alignEnd: false,
                                  in: CGRect(x: left, y: rowTop + (rowHeight - leftHeight) / 2, width: third, height: leftHeight))
                }

                // Centre caption.
                var y = rowTop + (rowHeight - centerHeight) / 2
                let titleHeight = PdfText.height("E-Ticket", title, width: third)
                PdfText.draw("E-Ticket", title, in: CGRect(x: left + third, y: y, width: third, height: titleHeight), align: .center)
                y += titleHeight + 2
                PdfText.draw("This is not a boarding pass", subtitle,
                             in: CGRect(x: left + third, y: y, width: third, height: PdfText.height("This is not a boarding pass", subtitle, width: third)),
                             align: .center)

                // IATA accredited-agent mark (white), right.
                let rightEdge = left + inner
                if let logo = a.iataLogo, let size = rightSize {
                    logo.draw(in: CGRect(x: rightEdge - size.width, y: rowTop + (rowHeight - size.height) / 2, width: size.width, height: size.height))
                } else {
                    drawBrandText("IATA", "ACCREDITED AGENT", alignEnd: true,
                                  in: CGRect(x: rightEdge - third, y: rowTop + (rowHeight - rightHeight) / 2, width: third, height: rightHeight))
                }
            }
            return height
        }
    }

    private static func brandTextHeight(_ title: String, _ sub: String, width: CGFloat) -> CGFloat {
        PdfText.height(title, PdfStyle(size: 16, bold: true, color: white, letterSpacing: 0.5), width: width)
            + PdfText.height(sub, PdfStyle(size: 8, color: white), width: width)
    }

    private static func drawBrandText(_ title: String, _ sub: String, alignEnd: Bool, in rect: CGRect) {
        let titleStyle = PdfStyle(size: 16, bold: true, color: white, letterSpacing: 0.5)
        let subStyle = PdfStyle(size: 8, color: white)
        let align: NSTextAlignment = alignEnd ? .right : .left
        let titleHeight = PdfText.height(title, titleStyle, width: rect.width)
        PdfText.draw(title, titleStyle, in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: titleHeight), align: align)
        PdfText.draw(sub, subStyle,
                     in: CGRect(x: rect.minX, y: rect.minY + titleHeight, width: rect.width, height: PdfText.height(sub, subStyle, width: rect.width)),
                     align: align)
    }

    // ── Meta row: booking · purchase · PNR (plain columns, no card) ───────────

    private static func metaRow(_ issued: String, _ ref: String) -> PdfBlock {
        PdfBlock { width, origin in
            let label = PdfStyle(size: 8, color: tertiary, letterSpacing: 0.6)
            func value(_ color: UIColor) -> PdfStyle { PdfStyle(size: 11, bold: true, color: color) }
            let cellWidth = (width - 2) / 3

            func cellHeight(_ labelText: String, _ valueText: String, _ w: CGFloat, _ color: UIColor) -> CGFloat {
                PdfText.height(labelText, label, width: w) + 4 + PdfText.height(valueText, value(color), width: w)
            }
            func drawCell(_ labelText: String, _ valueText: String, _ x: CGFloat, _ w: CGFloat, _ top: CGFloat, _ color: UIColor) {
                let labelHeight = PdfText.height(labelText, label, width: w)
                PdfText.draw(labelText, label, in: CGRect(x: x, y: top, width: w, height: labelHeight))
                PdfText.draw(valueText, value(color),
                             in: CGRect(x: x, y: top + labelHeight + 4, width: w, height: PdfText.height(valueText, value(color), width: w)))
            }

            let cells: [(String, String, UIColor, CGFloat)] = [
                ("BOOKING DATE", issued, ink, 0),
                ("PURCHASE DATE", issued, ink, 14),
                ("PNR NUMBER", ref, green, 14),
            ]
            let heights = cells.map { cellHeight($0.0, $0.1, cellWidth - $0.3, $0.2) }
            let rowHeight = max(30, heights.max() ?? 0)

            if let origin {
                var x = origin.x
                for (index, cell) in cells.enumerated() {
                    if index > 0 {
                        // divider(): 1 × 30 rule.
                        line.setFill()
                        UIRectFill(CGRect(x: x, y: origin.y + (rowHeight - 30) / 2, width: 1, height: 30))
                        x += 1
                    }
                    let w = cellWidth - cell.3
                    drawCell(cell.0, cell.1, x + cell.3, w, origin.y + (rowHeight - heights[index]) / 2, cell.2)
                    x += cellWidth
                }
            }
            return rowHeight
        }
    }

    /// A full-width dashed rule used to separate sections (matches the website
    /// print — no boxed cards).
    private static func dashDivider() -> PdfBlock {
        PdfBlock { width, origin in
            if let origin {
                drawDashedRule(from: origin.x, to: origin.x + width, bottom: origin.y + 1)
            }
            return 1
        }
    }

    private static func bookedByRow(_ barcodeData: String) -> PdfBlock {
        PdfBlock { width, origin in
            let mutedStyle = PdfStyle(size: 10.5, color: muted)
            let strongStyle = PdfStyle(size: 10.5, bold: true, color: ink)
            let lineRowHeight = max(13, PdfText.lineHeight(mutedStyle))
            let bookedByHeight = lineRowHeight + 8 + lineRowHeight
            let rowHeight = max(bookedByHeight, 52)

            if let origin {
                let top = origin.y + (rowHeight - bookedByHeight) / 2
                @MainActor
                func drawLine(_ icon: String, _ lead: String, _ value: String, _ y: CGFloat) {
                    var x = origin.x
                    drawIcon(icon, size: 13, color: green, at: CGPoint(x: x, y: y + (lineRowHeight - 13) / 2))
                    x += 13 + 8
                    let leadWidth = PdfText.width(lead, mutedStyle)
                    let textTop = y + (lineRowHeight - PdfText.lineHeight(mutedStyle)) / 2
                    PdfText.draw(lead, mutedStyle, in: CGRect(x: x, y: textTop, width: leadWidth + 1, height: PdfText.lineHeight(mutedStyle)))
                    x += leadWidth
                    PdfText.draw(value, strongStyle,
                                 in: CGRect(x: x, y: textTop, width: PdfText.width(value, strongStyle) + 1, height: PdfText.lineHeight(strongStyle)))
                }
                drawLine(icMail, "Booked by:  ", "Epic World Co., Ltd.", top)
                drawLine(icPhone, "Main Branch · ", "+95 9 787 844 882", top + lineRowHeight + 8)

                // pw.BarcodeWidget(code128, width: 240, height: 52, drawText: false)
                drawBarcode(barcodeData, in: CGRect(x: origin.x + width - 240, y: origin.y + (rowHeight - 52) / 2, width: 240, height: 52))
            }
            return rowHeight
        }
    }

    // ── Flight leg (full-width) ───────────────────────────────────────────────

    private static func flightLeg(_ leg: TripOptionModel, _ logo: UIImage?, isReturn: Bool) -> PdfBlock {
        PdfBlock { width, origin in
            let headingDate = DateFormat("EEE, MMM d").format(leg.departure)
            let headingStyle = PdfStyle(size: 11.5, bold: true, color: ink)
            let dateStyle = PdfStyle(size: 10, color: muted)
            let headingText = isReturn ? "Return flight" : "Departing flight"
            let headingHeight = max(13, PdfText.lineHeight(headingStyle), PdfText.lineHeight(dateStyle))

            // Times + route line.
            let timeStyle = PdfStyle(size: 20, bold: true, color: ink)
            let codeStyle = PdfStyle(size: 11, color: muted)
            let endpointHeight = PdfText.lineHeight(timeStyle) + 3 + PdfText.lineHeight(codeStyle)
            let smallStyle = PdfStyle(size: 9, color: tertiary)
            let stopsStyle = PdfStyle(size: 9, color: muted)
            let middleHeight = PdfText.lineHeight(smallStyle) + 4 + 12 + 4 + PdfText.lineHeight(stopsStyle)
            let timesHeight = max(endpointHeight, middleHeight)

            // Airline + flight number + class.
            let airlineStyle = PdfStyle(size: 11, bold: true, color: ink)
            let classStyle = PdfStyle(size: 10.5, bold: true, color: green)
            let classText = leg.travelClass.label
            let classWidth = PdfText.width(classText, classStyle)
            let logoSize = logo.map { containSize($0.size, CGSize(width: 42, height: 18)) }
            let leadWidth = logoSize?.width ?? 16
            let airlineText = "\(pdfSafe(leg.operatorName))  ·  \(flightNo(leg))"
            let airlineTextWidth = max(width - leadWidth - 9 - 8 - classWidth, 1)
            let airlineTextHeight = PdfText.height(airlineText, airlineStyle, width: airlineTextWidth)
            let airlineRowHeight = max(logoSize?.height ?? 16, airlineTextHeight, PdfText.lineHeight(classStyle))

            let height = headingHeight + 12 + timesHeight + 12 + airlineRowHeight

            if let origin {
                // Heading: plane icon + "Departing/Return flight · date".
                var x = origin.x
                var y = origin.y
                drawIcon(isReturn ? icFlightLand : icFlightTakeoff, size: 13, color: green,
                         at: CGPoint(x: x, y: y + (headingHeight - 13) / 2))
                x += 13 + 7
                let headingWidth = PdfText.width(headingText, headingStyle)
                PdfText.draw(headingText, headingStyle,
                             in: CGRect(x: x, y: y + (headingHeight - PdfText.lineHeight(headingStyle)) / 2, width: headingWidth + 1, height: PdfText.lineHeight(headingStyle)))
                x += headingWidth
                let dateText = "  ·  \(headingDate)"
                PdfText.draw(dateText, dateStyle,
                             in: CGRect(x: x, y: y + (headingHeight - PdfText.lineHeight(dateStyle)) / 2, width: PdfText.width(dateText, dateStyle) + 1, height: PdfText.lineHeight(dateStyle)))
                y += headingHeight + 12

                // Endpoints.
                func drawEndpoint(_ time: String, _ code: String, _ left: CGFloat, alignEnd: Bool) {
                    let top = y + (timesHeight - endpointHeight) / 2
                    let align: NSTextAlignment = alignEnd ? .right : .left
                    PdfText.draw(time, timeStyle, in: CGRect(x: left, y: top, width: 118, height: PdfText.lineHeight(timeStyle)), align: align)
                    PdfText.draw(code, codeStyle,
                                 in: CGRect(x: left, y: top + PdfText.lineHeight(timeStyle) + 3, width: 118, height: PdfText.lineHeight(codeStyle)),
                                 align: align)
                }
                drawEndpoint(Formatters.time12(leg.departure).uppercased(), leg.originCode, origin.x, alignEnd: false)
                drawEndpoint(Formatters.time12(leg.arrival).uppercased(), leg.destinationCode, origin.x + width - 118, alignEnd: true)

                // Middle: duration, dashed line with a plane, stops.
                let middleLeft = origin.x + 118
                let middleWidth = max(width - 236, 0)
                var my = y + (timesHeight - middleHeight) / 2
                PdfText.draw(Formatters.duration(leg.duration), smallStyle,
                             in: CGRect(x: middleLeft, y: my, width: middleWidth, height: PdfText.lineHeight(smallStyle)), align: .center)
                my += PdfText.lineHeight(smallStyle) + 4
                let dashWidth = max((middleWidth - 4 - 12 - 4) / 2, 0)
                drawDashedRule(from: middleLeft, to: middleLeft + dashWidth, bottom: my + (12 - 1) / 2 + 1)
                drawIcon(icFlight, size: 12, color: green, at: CGPoint(x: middleLeft + dashWidth + 4, y: my))
                drawDashedRule(from: middleLeft + dashWidth + 4 + 12 + 4, to: middleLeft + middleWidth, bottom: my + (12 - 1) / 2 + 1)
                my += 12 + 4
                let stopsText = leg.isDirect ? "Non-stop" : "\(leg.stops) stop\(leg.stops > 1 ? "s" : "")"
                PdfText.draw(stopsText, stopsStyle,
                             in: CGRect(x: middleLeft, y: my, width: middleWidth, height: PdfText.lineHeight(stopsStyle)), align: .center)
                y += timesHeight + 12

                // Airline + flight number + class pill.
                x = origin.x
                if let logo, let logoSize {
                    logo.draw(in: CGRect(x: x, y: y + (airlineRowHeight - logoSize.height) / 2, width: logoSize.width, height: logoSize.height))
                } else {
                    drawIcon(icFlight, size: 16, color: green, at: CGPoint(x: x, y: y + (airlineRowHeight - 16) / 2))
                }
                x += leadWidth + 9
                PdfText.draw(airlineText, airlineStyle,
                             in: CGRect(x: x, y: y + (airlineRowHeight - airlineTextHeight) / 2, width: airlineTextWidth, height: airlineTextHeight))
                // Class label — plain text in the system green (no badge/pill).
                PdfText.draw(classText, classStyle,
                             in: CGRect(x: origin.x + width - classWidth, y: y + (airlineRowHeight - PdfText.lineHeight(classStyle)) / 2, width: classWidth + 1, height: PdfText.lineHeight(classStyle)))
            }
            return height
        }
    }

    // ── Passengers ────────────────────────────────────────────────────────────

    private static func passengersHeader(_ count: Int) -> PdfBlock {
        PdfBlock { width, origin in
            let style = PdfStyle(size: 11, bold: true, color: muted, letterSpacing: 0.6)
            let text = "PASSENGERS (\(count))"
            let height = max(13, PdfText.lineHeight(style))
            if let origin {
                drawIcon(icPeople, size: 13, color: muted, at: CGPoint(x: origin.x, y: origin.y + (height - 13) / 2))
                PdfText.draw(text, style,
                             in: CGRect(x: origin.x + 13 + 6, y: origin.y + (height - PdfText.lineHeight(style)) / 2, width: width - 19, height: PdfText.lineHeight(style)))
            }
            return height
        }
    }

    private static func passengerRow(_ t: TicketModel, _ index: Int) -> PdfBlock {
        let hasReturn = t.inbound != nil
        let idBase = t.id.count >= 11 ? String(t.id.prefix(11)) : t.id
        let name = passengerName(t, index)
        let traveller = passengerAt(t, index)
        // The airline's ticket number when the backend has reported one, else the
        // booking reference — real, and what an agent can look the passenger up
        // by. Never a slice of a local UUID dressed up as a ticket number.
        let ticketNumber: String
        if let traveller, !traveller.ticketNumber.isEmpty {
            ticketNumber = traveller.ticketNumber
        } else {
            ticketNumber = !t.bookingReference.isEmpty
                ? "\(t.bookingReference)-\(index + 1)"
                : "\(idBase)\(index + 1)"
        }
        let document = traveller?.documentNumber ?? ""
        let phone = traveller?.phone ?? t.phone ?? ""

        var tableRows: [(route: String, sub: String)] = [(
            route: "\(t.outbound.originCode)-\(t.outbound.destinationCode)",
            sub: "\(DateFormat("dd-MMM").format(t.outbound.departure)) · \(flightNo(t.outbound))"
        )]
        if hasReturn, let inbound = t.inbound {
            tableRows.append((
                route: "\(inbound.originCode)-\(inbound.destinationCode)",
                sub: "\(DateFormat("dd-MMM").format(inbound.departure)) · \(flightNo(inbound))"
            ))
        }
        let idLines: [(icon: String, color: UIColor, label: String, value: String)] = [
            (icTicket, amber, "Ticket", ticketNumber),
            (icPassport, teal, "Passport", !document.isEmpty ? document : "-"),
            (icPhone, amber, "Phone", !phone.isEmpty ? phone : "-"),
        ]

        return PdfBlock { width, origin in
            let available = width - 14
            let leftWidth = available * 5 / 12
            let rightWidth = available * 7 / 12

            // ---- Left: identity.
            let nameStyle = PdfStyle(size: 12, bold: true, color: ink)
            let labelStyle = PdfStyle(size: 9.5, color: muted)
            let valueStyle = PdfStyle(size: 10, bold: true, color: ink)
            let nameRowHeight = max(22, PdfText.lineHeight(nameStyle))
            let valueWidth = max(leftWidth - 12 - 6 - 54, 1)
            let idHeights = idLines.map { line in
                max(12, PdfText.lineHeight(labelStyle), PdfText.height(line.value, valueStyle, width: valueWidth))
            }
            let leftHeight = nameRowHeight + 10 + idHeights.reduce(0) { $0 + $1 + 6 }

            // ---- Right: per-leg flight table.
            let headerStyle = PdfStyle(size: 8.5, color: tertiary)
            let routeStyle = PdfStyle(size: 11, bold: true, color: ink)
            let subStyle = PdfStyle(size: 8, color: muted)
            let cellStyle = PdfStyle(size: 10, bold: true, color: ink)
            let pillStyle = PdfStyle(size: 8, bold: true, color: greenDark)
            let unit = rightWidth / 11
            let flightWidth = unit * 5
            let headerHeight = PdfText.lineHeight(headerStyle)
            let rowHeights = tableRows.map { row in
                max(
                    PdfText.height(row.route, routeStyle, width: flightWidth) + 1 + PdfText.height(row.sub, subStyle, width: flightWidth),
                    PdfText.lineHeight(cellStyle),
                    2 + PdfText.lineHeight(pillStyle) + 2
                )
            }
            let rightHeight = headerHeight + rowHeights.reduce(0) { $0 + 8 + $1 }

            let height = max(leftHeight, rightHeight)

            if let origin {
                // Number badge + name.
                var y = origin.y
                let circle = CGRect(x: origin.x, y: y + (nameRowHeight - 22) / 2, width: 22, height: 22)
                green.setFill()
                UIBezierPath(ovalIn: circle).fill()
                let numberStyle = PdfStyle(size: 10, bold: true, color: white)
                PdfText.draw("\(index + 1)", numberStyle,
                             in: CGRect(x: circle.minX, y: circle.midY - PdfText.lineHeight(numberStyle) / 2, width: 22, height: PdfText.lineHeight(numberStyle)),
                             align: .center)
                let nameLeft = origin.x + 22 + 8
                PdfText.draw("MR \(name.uppercased())", nameStyle,
                             in: CGRect(x: nameLeft, y: y + (nameRowHeight - PdfText.lineHeight(nameStyle)) / 2, width: leftWidth - 30, height: PdfText.lineHeight(nameStyle)),
                             maxLines: 1, clip: true)
                y += nameRowHeight + 10

                // Ticket / passport / phone.
                for (lineIndex, line) in idLines.enumerated() {
                    let rowHeight = idHeights[lineIndex]
                    drawIcon(line.icon, size: 12, color: line.color, at: CGPoint(x: origin.x, y: y + (rowHeight - 12) / 2))
                    PdfText.draw(line.label, labelStyle,
                                 in: CGRect(x: origin.x + 18, y: y + (rowHeight - PdfText.lineHeight(labelStyle)) / 2, width: 54, height: PdfText.lineHeight(labelStyle)))
                    let valueHeight = PdfText.height(line.value, valueStyle, width: valueWidth)
                    PdfText.draw(line.value, valueStyle,
                                 in: CGRect(x: origin.x + 18 + 54, y: y + (rowHeight - valueHeight) / 2, width: valueWidth, height: valueHeight))
                    y += rowHeight + 6
                }

                // Table header.
                let right = origin.x + leftWidth + 14
                var ty = origin.y
                let columns: [(String, CGFloat, CGFloat, NSTextAlignment)] = [
                    ("Flight", 0, unit * 5, .left),
                    ("Seat", unit * 5, unit * 2, .center),
                    ("Bags", unit * 7, unit * 2, .center),
                    ("Status", unit * 9, unit * 2, .center),
                ]
                for column in columns {
                    PdfText.draw(column.0, headerStyle, in: CGRect(x: right + column.1, y: ty, width: column.2, height: headerHeight), align: column.3)
                }
                ty += headerHeight

                // One row per leg.
                for (rowIndex, row) in tableRows.enumerated() {
                    ty += 8
                    let rowHeight = rowHeights[rowIndex]
                    let routeHeight = PdfText.height(row.route, routeStyle, width: flightWidth)
                    let subHeight = PdfText.height(row.sub, subStyle, width: flightWidth)
                    let columnTop = ty + (rowHeight - (routeHeight + 1 + subHeight)) / 2
                    PdfText.draw(row.route, routeStyle, in: CGRect(x: right, y: columnTop, width: flightWidth, height: routeHeight))
                    PdfText.draw(row.sub, subStyle, in: CGRect(x: right, y: columnTop + routeHeight + 1, width: flightWidth, height: subHeight))
                    let cellTop = ty + (rowHeight - PdfText.lineHeight(cellStyle)) / 2
                    PdfText.draw("-", cellStyle, in: CGRect(x: right + unit * 5, y: cellTop, width: unit * 2, height: PdfText.lineHeight(cellStyle)), align: .center)
                    PdfText.draw("20kgs", cellStyle, in: CGRect(x: right + unit * 7, y: cellTop, width: unit * 2, height: PdfText.lineHeight(cellStyle)), align: .center)
                    drawPill("OK", background: greenSurface, foreground: greenDark, small: true,
                             centeredIn: CGRect(x: right + unit * 9, y: ty, width: unit * 2, height: rowHeight))
                    ty += rowHeight
                }
            }
            return height
        }
    }

    // ── Important information (paginates onto following A4 pages) ──────────────

    private static func importantInfo() -> [PdfBlock] {
        // Full policy set, shared verbatim with the in-app e-ticket card
        // (`kImportantInfoSections`). Rendered single-column so it paginates
        // cleanly across the A4 pages.
        var blocks: [PdfBlock] = [
            PdfBlock { width, origin in
                let style = PdfStyle(size: 11, bold: true, color: muted, letterSpacing: 0.6)
                let height = PdfText.height("IMPORTANT INFORMATION", style, width: width)
                if let origin {
                    PdfText.draw("IMPORTANT INFORMATION", style, in: CGRect(x: origin.x, y: origin.y, width: width, height: height))
                }
                return height
            },
            spacer(10),
        ]
        for section in kImportantInfoSections {
            blocks.append(infoSection(section[0], section[1]))
        }
        return blocks
    }

    private static func infoSection(_ title: String, _ body: String) -> PdfBlock {
        let lines = body.components(separatedBy: "\n")
        return PdfBlock { width, origin in
            let titleStyle = PdfStyle(size: 10.5, bold: true, color: ink)
            let titleText = pdfSafe(title)
            let titleWidth = max(width - 3 - 7, 1)
            let titleHeight = PdfText.height(titleText, titleStyle, width: titleWidth)
            let titleRowHeight = max(11, titleHeight)
            let lineWidth = max(width - 10, 1)
            let lineHeights = lines.map { infoLine($0, width: lineWidth, at: nil) }
            let height = titleRowHeight + 4 + lineHeights.reduce(0, +) + 11

            if let origin {
                green.setFill()
                UIRectFill(CGRect(x: origin.x, y: origin.y + (titleRowHeight - 11) / 2, width: 3, height: 11))
                PdfText.draw(titleText, titleStyle,
                             in: CGRect(x: origin.x + 3 + 7, y: origin.y + (titleRowHeight - titleHeight) / 2, width: titleWidth, height: titleHeight))
                var y = origin.y + titleRowHeight + 4
                for (index, line) in lines.enumerated() {
                    _ = infoLine(line, width: lineWidth, at: CGPoint(x: origin.x + 10, y: y))
                    y += lineHeights[index]
                }
            }
            return height
        }
    }

    /// Renders one markup line: `- ` / `-- ` bullets, `! ` italic note, else a
    /// paragraph. URL tokens inside are tinted green. Returns its height.
    private static func infoLine(_ raw: String, width: CGFloat, at origin: CGPoint?) -> CGFloat {
        var text = raw
        var level = 0
        var note = false
        if text.hasPrefix("-- ") {
            level = 2
            text = String(text.dropFirst(3))
        } else if text.hasPrefix("- ") {
            level = 1
            text = String(text.dropFirst(2))
        } else if text.hasPrefix("! ") {
            note = true
            text = String(text.dropFirst(2))
        }
        text = pdfSafe(text)

        if note {
            let style = PdfStyle(size: 8.5, italic: true, color: tertiary, lineSpacing: 1.5)
            let height = PdfText.height(text, style, width: width)
            if let origin {
                PdfText.draw(text, style, in: CGRect(x: origin.x, y: origin.y + 2, width: width, height: height))
            }
            return 2 + height + 3
        }

        if level == 0 {
            let rich = infoRich(text)
            let height = PdfText.height(rich, width: width)
            if let origin {
                PdfText.draw(rich, in: CGRect(x: origin.x, y: origin.y, width: width, height: height))
            }
            return height + 3
        }

        let indent: CGFloat = level == 2 ? 16.0 : 3.0
        let textLeft = indent + 3.5 + 6
        let textWidth = max(width - textLeft, 1)
        let rich = infoRich(text)
        let textHeight = PdfText.height(rich, width: textWidth)
        let rowHeight = max(3.5 + 3.5, textHeight)
        if let origin {
            drawBulletMarker(level, at: CGPoint(x: origin.x + indent, y: origin.y + 3.5))
            PdfText.draw(rich, in: CGRect(x: origin.x + textLeft, y: origin.y, width: textWidth, height: textHeight))
        }
        return rowHeight + 3
    }

    /// A small drawn bullet (filled dot for level 1, ring for level 2) — drawn as
    /// a shape rather than a glyph so it never depends on a Unicode font.
    private static func drawBulletMarker(_ level: Int, at point: CGPoint) {
        let rect = CGRect(x: point.x, y: point.y, width: 3.5, height: 3.5)
        if level == 2 {
            let ring = UIBezierPath(ovalIn: rect.insetBy(dx: 0.4, dy: 0.4))
            ring.lineWidth = 0.8
            muted.setStroke()
            ring.stroke()
        } else {
            green.setFill()
            UIBezierPath(ovalIn: rect).fill()
        }
    }

    /// Swaps glyphs the base PDF font can't render (— – ×) for ASCII equivalents.
    private static func pdfSafe(_ s: String) -> String {
        s.replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "×", with: "x")
    }

    /// A paragraph of text with URL tokens highlighted in the brand green.
    private static func infoRich(_ text: String) -> PdfRich {
        let base = PdfStyle(size: 8.5, color: muted, lineSpacing: 1.5)
        let link = PdfStyle(size: 8.5, bold: true, color: green, lineSpacing: 1.5)
        let spans = text.components(separatedBy: " ").map { token in
            (text: "\(token) ", style: isUrl(token) ? link : base)
        }
        return PdfRich(spans: spans, size: 8.5, lineSpacing: 1.5)
    }

    private static func isUrl(_ token: String) -> Bool {
        token.hasPrefix("http")
            || token.hasPrefix("www")
            || token.contains(".com")
            || token.contains(".htm")
    }

    // ── Small helpers ─────────────────────────────────────────────────────────

    private static func spacer(_ height: CGFloat) -> PdfBlock {
        PdfBlock { _, _ in height }
    }

    private static func drawPill(_ text: String, background: UIColor, foreground: UIColor, small: Bool, centeredIn rect: CGRect) {
        let style = PdfStyle(size: small ? 8 : 9.5, bold: true, color: foreground)
        let horizontal: CGFloat = small ? 7 : 10
        let vertical: CGFloat = small ? 2 : 4
        let textWidth = PdfText.width(text, style)
        let size = CGSize(width: textWidth + horizontal * 2, height: PdfText.lineHeight(style) + vertical * 2)
        let pill = CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
        background.setFill()
        UIBezierPath(roundedRect: pill, cornerRadius: min(20, size.height / 2)).fill()
        PdfText.draw(text, style, in: CGRect(x: pill.minX + horizontal, y: pill.minY + vertical, width: textWidth + 1, height: PdfText.lineHeight(style)))
    }

    /// A 1pt dashed bottom border (`BorderStyle.dashed`, pattern 3/3) ending at
    /// `bottom`.
    private static func drawDashedRule(from x0: CGFloat, to x1: CGFloat, bottom: CGFloat) {
        guard x1 > x0, let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.setStrokeColor(line.cgColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [3, 3])
        context.move(to: CGPoint(x: x0, y: bottom - 0.5))
        context.addLine(to: CGPoint(x: x1, y: bottom - 0.5))
        context.strokePath()
        context.restoreGState()
    }

    /// Draws a Material icon `path` (24×24 viewBox) at `size`, tinted `color`.
    private static func drawIcon(_ path: String, size: CGFloat, color: UIColor, at point: CGPoint) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let scale = size / 24
        var transform = CGAffineTransform(translationX: point.x, y: point.y).scaledBy(x: scale, y: scale)
        guard let scaled = SvgPathData.cgPath(path).copy(using: &transform) else { return }
        context.saveGState()
        context.addPath(scaled)
        context.setFillColor(color.cgColor)
        context.fillPath()
        context.restoreGState()
    }

    /// `pw.BarcodeWidget(barcode: Barcode.code128(), drawText: false, color: _ink)`.
    private static func drawBarcode(_ data: String, in rect: CGRect) {
        let bars = Barcode.code128Bars(data)
        guard !bars.isEmpty else { return }
        let module = rect.width / CGFloat(bars.count)
        ink.setFill()
        var index = 0
        while index < bars.count {
            guard bars[index] else { index += 1; continue }
            var end = index
            while end < bars.count && bars[end] { end += 1 }
            UIRectFill(CGRect(x: rect.minX + CGFloat(index) * module, y: rect.minY, width: CGFloat(end - index) * module, height: rect.height))
            index = end
        }
    }

    private static func drawGradient(in path: CGPath, rect: CGRect, colors: [UIColor], stops: [CGFloat]) {
        guard let context = UIGraphicsGetCurrentContext(),
              let gradient = CGGradient(
                colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                colors: colors.map(\.cgColor) as CFArray,
                locations: stops
              ) else { return }
        context.saveGState()
        context.addPath(path)
        context.clip()
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.minX, y: rect.midY),
            end: CGPoint(x: rect.maxX, y: rect.midY),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        context.restoreGState()
    }

    /// `BoxFit.contain` of an image into a box.
    fileprivate static func containSize(_ image: CGSize, _ box: CGSize) -> CGSize {
        guard image.width > 0, image.height > 0 else { return .zero }
        let scale = min(box.width / image.width, box.height / image.height)
        return CGSize(width: image.width * scale, height: image.height * scale)
    }
}

// ── Layout primitives ─────────────────────────────────────────────────────────

/// One top-level child of the page body: measuring it (origin nil) and drawing
/// it (origin set) run the same code, which returns the height at `width`.
private struct PdfBlock {
    let layout: (_ width: CGFloat, _ origin: CGPoint?) -> CGFloat

    init(_ layout: @escaping (_ width: CGFloat, _ origin: CGPoint?) -> CGFloat) {
        self.layout = layout
    }

    func measure(_ width: CGFloat) -> CGFloat { layout(width, nil) }

    func paint(_ rect: CGRect) { _ = layout(rect.width, rect.origin) }
}

/// `pw.TextStyle` with the base Helvetica family.
private struct PdfStyle {
    var size: CGFloat
    var bold = false
    var italic = false
    var color: UIColor
    var letterSpacing: CGFloat = 0
    /// `pw.TextStyle.lineSpacing`: extra points between lines.
    var lineSpacing: CGFloat = 0

    var font: UIFont {
        let name: String
        switch (bold, italic) {
        case (true, true): name = "Helvetica-BoldOblique"
        case (true, false): name = "Helvetica-Bold"
        case (false, true): name = "Helvetica-Oblique"
        case (false, false): name = "Helvetica"
        }
        return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    var attributes: [NSAttributedString.Key: Any] {
        [
            .font: font,
            .foregroundColor: color,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
            .kern: letterSpacing,
        ]
    }
}

/// `pw.RichText` of same-sized spans.
private struct PdfRich {
    let spans: [(text: String, style: PdfStyle)]
    let size: CGFloat
    let lineSpacing: CGFloat

    var attributed: NSAttributedString {
        let result = NSMutableAttributedString()
        for span in spans {
            result.append(NSAttributedString(string: span.text, attributes: span.style.attributes))
        }
        return result
    }
}

/// Core Text line layout with the `pdf` package's Helvetica line box.
private enum PdfText {
    static func lineHeight(_ style: PdfStyle) -> CGFloat { lineHeight(size: style.size) }

    static func lineHeight(size: CGFloat) -> CGFloat { size * (0.718 + 0.207) }

    static func ascent(size: CGFloat) -> CGFloat { size * 0.718 }

    /// The natural single-line width.
    static func width(_ text: String, _ style: PdfStyle) -> CGFloat {
        let attributed = NSAttributedString(string: text, attributes: style.attributes)
        let line = CTLineCreateWithAttributedString(attributed as CFAttributedString)
        return lineWidth(line)
    }

    static func height(_ text: String, _ style: PdfStyle, width: CGFloat, maxLines: Int? = nil) -> CGFloat {
        let attributed = NSAttributedString(string: text, attributes: style.attributes)
        let count = lines(attributed, width: width, maxLines: maxLines).count
        return blockHeight(lines: count, size: style.size, lineSpacing: style.lineSpacing)
    }

    static func height(_ rich: PdfRich, width: CGFloat) -> CGFloat {
        let count = lines(rich.attributed, width: width, maxLines: nil).count
        return blockHeight(lines: count, size: rich.size, lineSpacing: rich.lineSpacing)
    }

    static func draw(
        _ text: String,
        _ style: PdfStyle,
        in rect: CGRect,
        align: NSTextAlignment = .left,
        maxLines: Int? = nil,
        clip: Bool = false
    ) {
        let attributed = NSAttributedString(string: text, attributes: style.attributes)
        draw(lines(attributed, width: rect.width, maxLines: maxLines), size: style.size, lineSpacing: style.lineSpacing, in: rect, align: align, clip: clip)
    }

    static func draw(_ rich: PdfRich, in rect: CGRect) {
        draw(lines(rich.attributed, width: rect.width, maxLines: nil), size: rich.size, lineSpacing: rich.lineSpacing, in: rect, align: .left, clip: false)
    }

    private static func blockHeight(lines count: Int, size: CGFloat, lineSpacing: CGFloat) -> CGFloat {
        let lines = max(count, 1)
        return CGFloat(lines) * lineHeight(size: size) + CGFloat(lines - 1) * lineSpacing
    }

    private static func lineWidth(_ line: CTLine) -> CGFloat {
        CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)) - CGFloat(CTLineGetTrailingWhitespaceWidth(line))
    }

    /// Word-wrapped lines, honouring explicit line breaks.
    private static func lines(_ attributed: NSAttributedString, width: CGFloat, maxLines: Int?) -> [CTLine] {
        let length = attributed.length
        guard length > 0 else { return [] }
        let typesetter = CTTypesetterCreateWithAttributedString(attributed as CFAttributedString)
        var result: [CTLine] = []
        var start = 0
        let available = Double(max(width, 1) + 0.5)
        while start < length {
            if let maxLines, result.count >= maxLines { break }
            var count = CTTypesetterSuggestLineBreak(typesetter, start, available)
            if count <= 0 { count = 1 }
            result.append(CTTypesetterCreateLine(typesetter, CFRange(location: start, length: count)))
            start += count
        }
        return result
    }

    private static func draw(
        _ lines: [CTLine],
        size: CGFloat,
        lineSpacing: CGFloat,
        in rect: CGRect,
        align: NSTextAlignment,
        clip: Bool
    ) {
        guard !lines.isEmpty, let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        if clip { context.clip(to: rect) }
        // The PDF context is flipped (y down); Core Text draws y up.
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        for (index, line) in lines.enumerated() {
            let width = lineWidth(line)
            let x: CGFloat
            switch align {
            case .center: x = rect.minX + (rect.width - width) / 2
            case .right: x = rect.maxX - width
            default: x = rect.minX
            }
            let baseline = rect.minY + CGFloat(index) * (lineHeight(size: size) + lineSpacing) + ascent(size: size)
            context.textPosition = CGPoint(x: x, y: baseline)
            CTLineDraw(line, context)
        }
        context.restoreGState()
    }
}

/// Brand + icon assets loaded once per PDF build. Every field is optional and
/// each loader is guarded, so a missing asset (or being offline) degrades to a
/// text/monogram fallback instead of failing the whole export.
@MainActor
private struct Assets {
    let epicLogo: UIImage?
    let iataLogo: UIImage?
    let airlineLogo: UIImage?
    let airlineLogoReturn: UIImage?

    static func load(_ t: TicketModel) async -> Assets {
        var epic: UIImage?
        var iata: UIImage?
        var airline: UIImage?
        var airlineReturn: UIImage?

        if let image = AppImage.uiImage(for: AppAssets.brandLogo) {
            epic = tintWhite(image)
        }

        iata = AppImage.uiImage(for: AppAssets.brandLogoWhite)

        let url = t.outbound.operatorLogoUrl
        if !url.isEmpty {
            airline = try? await ImageLoader.load(url)
        }

        // Return leg may be a different carrier — load its logo too.
        let returnUrl = t.inbound?.operatorLogoUrl ?? ""
        if !returnUrl.isEmpty {
            airlineReturn = try? await ImageLoader.load(returnUrl)
        }

        return Assets(
            epicLogo: epic,
            iataLogo: iata,
            airlineLogo: airline,
            airlineLogoReturn: airlineReturn
        )
    }

    /// Repaints every non-transparent pixel white (keeping the alpha), so a
    /// coloured logo reads cleanly on the green header — the tint is baked into
    /// the bitmap here, as the Dart version does.
    private static func tintWhite(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.withTintColor(.white, renderingMode: .alwaysOriginal).draw(at: .zero)
        }
    }
}

/// Parses SVG path data (`M L H V C S Q T Z`, absolute and relative) into a
/// `CGPath` — enough for the Material icon paths above.
private enum SvgPathData {
    private static var cache: [String: CGPath] = [:]
    private static let tokenPattern = try! NSRegularExpression(
        pattern: #"[A-Za-z]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?"#
    )

    static func cgPath(_ data: String) -> CGPath {
        if let cached = cache[data] { return cached }
        let path = parse(data)
        cache[data] = path
        return path
    }

    private enum Token {
        case command(Character)
        case number(CGFloat)
    }

    private static func tokens(_ data: String) -> [Token] {
        let range = NSRange(data.startIndex..., in: data)
        return tokenPattern.matches(in: data, range: range).compactMap { match in
            guard let r = Range(match.range, in: data) else { return nil }
            let text = String(data[r])
            if let first = text.first, first.isLetter, text.count == 1 { return .command(first) }
            return Double(text).map { .number(CGFloat($0)) }
        }
    }

    private static func parse(_ data: String) -> CGPath {
        let path = CGMutablePath()
        let list = tokens(data)
        var index = 0
        var command: Character = "M"
        var current = CGPoint.zero
        var start = CGPoint.zero
        var lastCubicControl: CGPoint?
        var lastQuadControl: CGPoint?

        func hasNumber() -> Bool {
            if index < list.count, case .number = list[index] { return true }
            return false
        }
        func next() -> CGFloat {
            guard index < list.count, case .number(let value) = list[index] else { return 0 }
            index += 1
            return value
        }

        while index < list.count {
            if case .command(let c) = list[index] {
                command = c
                index += 1
            } else if command == "M" {
                command = "L" // implicit lineto after a moveto pair
            } else if command == "m" {
                command = "l"
            }
            let relative = command.isLowercase
            let origin = relative ? current : .zero

            switch command {
            case "M", "m":
                current = CGPoint(x: origin.x + next(), y: origin.y + next())
                start = current
                path.move(to: current)
                lastCubicControl = nil
                lastQuadControl = nil
            case "L", "l":
                current = CGPoint(x: origin.x + next(), y: origin.y + next())
                path.addLine(to: current)
                lastCubicControl = nil
                lastQuadControl = nil
            case "H", "h":
                current = CGPoint(x: (relative ? current.x : 0) + next(), y: current.y)
                path.addLine(to: current)
                lastCubicControl = nil
                lastQuadControl = nil
            case "V", "v":
                current = CGPoint(x: current.x, y: (relative ? current.y : 0) + next())
                path.addLine(to: current)
                lastCubicControl = nil
                lastQuadControl = nil
            case "C", "c":
                let c1 = CGPoint(x: origin.x + next(), y: origin.y + next())
                let c2 = CGPoint(x: origin.x + next(), y: origin.y + next())
                let end = CGPoint(x: origin.x + next(), y: origin.y + next())
                path.addCurve(to: end, control1: c1, control2: c2)
                lastCubicControl = c2
                lastQuadControl = nil
                current = end
            case "S", "s":
                let c1 = lastCubicControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                let c2 = CGPoint(x: origin.x + next(), y: origin.y + next())
                let end = CGPoint(x: origin.x + next(), y: origin.y + next())
                path.addCurve(to: end, control1: c1, control2: c2)
                lastCubicControl = c2
                lastQuadControl = nil
                current = end
            case "Q", "q":
                let control = CGPoint(x: origin.x + next(), y: origin.y + next())
                let end = CGPoint(x: origin.x + next(), y: origin.y + next())
                path.addQuadCurve(to: end, control: control)
                lastQuadControl = control
                lastCubicControl = nil
                current = end
            case "T", "t":
                let control = lastQuadControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                let end = CGPoint(x: origin.x + next(), y: origin.y + next())
                path.addQuadCurve(to: end, control: control)
                lastQuadControl = control
                lastCubicControl = nil
                current = end
            case "Z", "z":
                path.closeSubpath()
                current = start
                lastCubicControl = nil
                lastQuadControl = nil
                // A number straight after Z restarts an implicit lineto.
                if hasNumber() { command = "L" }
            default:
                // Unsupported command (arcs are not used by these icons): skip
                // its numbers.
                while hasNumber() { index += 1 }
            }
        }
        return path
    }
}

/// `Color(0xAARRGGBB)` as a `UIColor` (Dart `PdfColor.fromInt`).
private func pdfColor(_ argb: UInt32) -> UIColor {
    UIColor(
        red: CGFloat((argb >> 16) & 0xFF) / 255,
        green: CGFloat((argb >> 8) & 0xFF) / 255,
        blue: CGFloat(argb & 0xFF) / 255,
        alpha: CGFloat((argb >> 24) & 0xFF) / 255
    )
}

/// Dart VM `String.hashCode` (Jenkins one-at-a-time over UTF-16 code units,
/// 30-bit) — the mock flight number derives from it, so the same ticket prints
/// the same number on both platforms.
private func dartHashCode(_ value: String) -> Int {
    var hash: UInt32 = 0
    for unit in value.utf16 {
        hash = hash &+ UInt32(unit)
        hash = hash &+ (hash << 10)
        hash ^= hash >> 6
    }
    hash = hash &+ (hash << 3)
    hash ^= hash >> 11
    hash = hash &+ (hash << 15)
    hash &= (1 << 30) - 1
    return hash == 0 ? 1 : Int(hash)
}
