import Cocoa
import Foundation
try FileManager.default.createDirectory(atPath: "AppIcon.iconset", withIntermediateDirectories: true)
for size in [16,32,128,256,512] {
    for scale in [1,2] {
        let px = size * scale
        let image = NSImage(size: NSSize(width: px, height: px))
        image.lockFocus()
        let k = CGFloat(px) / 1024
        let transform = NSAffineTransform(); transform.scale(by: k); transform.concat()
        let base = NSBezierPath(roundedRect: NSRect(x: 32,y: 32,width: 960,height: 960), xRadius: 212,yRadius: 212)
        NSColor(calibratedWhite: 0.08, alpha: 1).setFill();base.fill()
        let panel = NSBezierPath(roundedRect: NSRect(x: 190,y: 245,width: 644,height: 630),xRadius: 90,yRadius: 90)
        NSColor.black.setFill();panel.fill()
        NSGraphicsContext.saveGraphicsState();panel.addClip()
        NSGradient(starting: NSColor(calibratedRed: 0.22,green: 0.8,blue: 0.96,alpha: 0.9), ending: .clear)!.draw(in:NSRect(x:190,y:245,width:644,height:220),angle:90)
        NSGraphicsContext.restoreGraphicsState()
        let bubble = NSBezierPath(roundedRect: NSRect(x: 345,y: 470,width: 330,height: 220),xRadius: 60,yRadius: 60)
        NSColor(calibratedWhite:0.94,alpha:1).setStroke();bubble.lineWidth=20;bubble.stroke()
        let tail=NSBezierPath();tail.move(to:NSPoint(x:390,y:477));tail.line(to:NSPoint(x:390,y:430));tail.line(to:NSPoint(x:452,y:478));tail.lineWidth=20;tail.stroke()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data:image.tiffRepresentation!)!
        let name = "AppIcon.iconset/icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:name))
    }
}
