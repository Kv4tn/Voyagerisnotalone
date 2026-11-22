// Renders every page of a PDF to page<N>.png for visual review of reports.
// Usage: osascript -l JavaScript pdf_to_png.js /abs/report.pdf /abs/output_dir
ObjC.import('AppKit');
ObjC.import('Quartz');

function run(argv) {
    if (argv.length !== 2) {
        throw new Error('usage: osascript -l JavaScript pdf_to_png.js report.pdf output_dir');
    }
    const doc = $.PDFDocument.alloc.initWithURL($.NSURL.fileURLWithPath(argv[0]));
    if (doc.isNil()) {
        throw new Error('cannot open ' + argv[0]);
    }
    const count = doc.pageCount;
    for (let i = 0; i < count; i++) {
        const image = doc.pageAtIndex(i).thumbnailOfSizeForBox($.NSMakeSize(620, 877), $.kPDFDisplayBoxMediaBox);
        const rep = $.NSBitmapImageRep.imageRepWithData(image.TIFFRepresentation);
        const png = rep.representationUsingTypeProperties($.NSBitmapImageFileTypePNG, $());
        png.writeToFileAtomically(argv[1] + '/page' + (i + 1) + '.png', true);
    }
    return 'pages: ' + count;
}
