// Prints an HTML file to a paginated A4 PDF with the text system built into macOS.
// Runs on stock macOS via JavaScript for Automation, no compiler or packages needed.
// Usage: osascript -l JavaScript html_to_pdf.js input.html output.pdf
ObjC.import('AppKit');

function run(argv) {
    if (argv.length !== 2) {
        throw new Error('usage: osascript -l JavaScript html_to_pdf.js input.html output.pdf');
    }
    const htmlPath = $(argv[0]).stringByStandardizingPath;
    const pdfPath = $(argv[1]).stringByStandardizingPath;

    $.NSApplication.sharedApplication;

    const data = $.NSData.dataWithContentsOfFile(htmlPath);
    if (data.isNil()) {
        throw new Error('cannot read ' + argv[0]);
    }
    const baseURL = $.NSURL.fileURLWithPath(htmlPath.stringByDeletingLastPathComponent);
    const text = $.NSAttributedString.alloc.initWithHTMLBaseURLDocumentAttributes(data, baseURL, null);
    if (text.isNil()) {
        throw new Error('HTML import failed');
    }

    const paperWidth = 595.28;   // A4 in points
    const paperHeight = 841.89;
    const margin = 42;
    const columnWidth = paperWidth - 2 * margin;

    const view = $.NSTextView.alloc.initWithFrame($.NSMakeRect(0, 0, columnWidth, paperHeight));
    view.horizontallyResizable = false;
    view.verticallyResizable = true;
    view.textContainer.widthTracksTextView = true;
    view.textContainer.containerSize = $.NSMakeSize(columnWidth, 1.0e7);
    view.textStorage.setAttributedString(text);
    view.layoutManager.ensureLayoutForTextContainer(view.textContainer);
    view.sizeToFit;

    const info = $.NSPrintInfo.sharedPrintInfo.copy;
    info.paperSize = $.NSMakeSize(paperWidth, paperHeight);
    info.topMargin = margin;
    info.bottomMargin = margin;
    info.leftMargin = margin;
    info.rightMargin = margin;
    info.horizontalPagination = $.NSPrintingPaginationModeFit;
    info.verticalPagination = $.NSPrintingPaginationModeAutomatic;
    info.verticallyCentered = false;
    info.horizontallyCentered = false;
    info.jobDisposition = $.NSPrintSaveJob;
    info.dictionary.setObjectForKey($.NSURL.fileURLWithPath(pdfPath), $.NSPrintJobSavingURL);

    const operation = $.NSPrintOperation.printOperationWithViewPrintInfo(view, info);
    operation.showsPrintPanel = false;
    operation.showsProgressPanel = false;
    if (!operation.runOperation) {
        throw new Error('print operation failed');
    }
    return 'PDF written: ' + pdfPath.js;
}
