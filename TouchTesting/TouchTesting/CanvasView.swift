import UIKit

internal typealias ColorValues = (red:CGFloat, green: CGFloat, blue: CGFloat)

internal enum DrawColors {
    case startingColor
    case endingColor
    case circleColor
    
    var values: ColorValues {
        switch self {
        case .startingColor:
            return (red: CGFloat(0.10), green: CGFloat(0.74), blue: 1)
        case .endingColor:
            return (red: CGFloat(0.4), green: CGFloat(0.20), blue: 1)
        case .circleColor:
            return (red: CGFloat(0.10), green: CGFloat(0.74), blue: 1)
        }
    }
    
    var color: UIColor{
        return UIColor(red: values.red, green: values.green, blue: values.blue, alpha:1.00)
    }
    var cgColor: CGColor {
        return color.cgColor
    }
    
    func difference(_ drawColor: DrawColors) -> ColorValues {
        let values = self.values
        let otherValues = drawColor.values
        return (red: values.red - otherValues.red, green: values.green - otherValues.green, blue: values.blue - otherValues.blue)
    }
    
}

internal let BEZIER_POINT_INTERVAL: TimeInterval = 0.4
internal let TIME_INTERVAL: TimeInterval = 0.25
internal let COLOR_CHANGE_FINISH: TimeInterval = 0.2
internal let CIRCLE_WIDTH_HEIGHT: CGFloat = 15
internal let MINIMUM_CIRCLE_WIDTH: CGFloat = 4
internal let START_WIDTH: CGFloat = 9
internal let END_WIDTH: CGFloat = 3

internal class DrawPoint {
    var date = Date()
    var shape: CAShapeLayer!
    var difference: ColorValues!
    
    init(bezierPath: UIBezierPath){
        difference = DrawColors.startingColor.difference(DrawColors.endingColor)
        
        shape = CAShapeLayer()
        shape.strokeColor = DrawColors.startingColor.cgColor
        shape.path = bezierPath.cgPath
        shape.lineWidth = START_WIDTH
    }
    
    func updateShapeColor(){
        let timeDifference = Double(date.timeIntervalSinceNow) / COLOR_CHANGE_FINISH
        if timeDifference >= 1 { return }
        
        let lineWidth = shape.lineWidth + ((START_WIDTH - END_WIDTH) * CGFloat(timeDifference))
        let startingValues = DrawColors.startingColor.values
        let red = startingValues.red + (CGFloat(timeDifference) * difference.red)
        let blue = startingValues.blue + (CGFloat(timeDifference) * difference.blue)
        let green = startingValues.green + (CGFloat(timeDifference) * difference.green)
        
        if lineWidth > END_WIDTH {
            shape.lineWidth = lineWidth
        }
        shape.strokeColor = UIColor(red: red, green: green, blue: blue, alpha: 1).cgColor
        shape.needsLayout()
    }
}

public class CanvasView: UIView {
    
    public let shouldInterpolate = true
    private var waitingPoints = [CGPoint]()
    private var allPoints = [CGPoint]()
    private var touchPoints = [CGPoint]()
    private let circleLayer = CAShapeLayer()
    private let drawLayer = CAShapeLayer()
    private var drawPoints = [DrawPoint]()
    private var touchEnded: Date?
    private var firstPoint: DrawPoint!
    
    var timer: Timer!
    
    public init(frame: CGRect, withPoints touchPoints:[CGPoint]) {
        super.init(frame: frame)
        
        backgroundColor = .clear
        
        allPoints.append(contentsOf: touchPoints)
        self.touchPoints.append(contentsOf: touchPoints)
        waitingPoints.append(contentsOf: touchPoints)
        
        if let point = waitingPoints.last {
            let circleRect = CGRect(x: point.x - (CIRCLE_WIDTH_HEIGHT/2), y: point.y - (CIRCLE_WIDTH_HEIGHT/2), width: CIRCLE_WIDTH_HEIGHT, height: CIRCLE_WIDTH_HEIGHT)
            circleLayer.path = UIBezierPath(roundedRect: circleRect, cornerRadius: CIRCLE_WIDTH_HEIGHT/2).cgPath
            circleLayer.fillColor = DrawColors.circleColor.cgColor
        }
        
        drawLayer.lineWidth = END_WIDTH
        drawLayer.strokeColor = DrawColors.endingColor.cgColor
        drawLayer.fillColor = nil
        redrawBezier()
        
        if waitingPoints.count >= 2 { redraw() }
        
        timer = Timer(timeInterval: 0.01, repeats: true, block: { (timer) in
            DispatchQueue.main.async {
                self.drawPoints.forEach({ (point) in point.updateShapeColor() })
                if self.firstPoint != nil { debugPrint("First Point Line: ", self.firstPoint.shape.lineWidth) }
                if self.touchEnded != nil { self.updateCircle() }
            }
        })
        timer.fire()
        RunLoop.main.add(timer, forMode: .commonModes)
        
        layer.addSublayer(circleLayer)
        layer.addSublayer(drawLayer)
    }
    
    func updateCircle(){
        let width = circleLayer.path!.boundingBox.width
        if width <= MINIMUM_CIRCLE_WIDTH {
            circleLayer.removeFromSuperlayer()
            return
        }
        if let point = allPoints.last {
            
            let difference = DrawColors.circleColor.difference(DrawColors.endingColor)
            let timeDifference = Double(touchEnded!.timeIntervalSinceNow) / COLOR_CHANGE_FINISH
            let startingValues = DrawColors.circleColor.values
            
            let red = startingValues.red + (CGFloat(timeDifference) * difference.red)
            let blue = startingValues.blue + (CGFloat(timeDifference) * difference.blue)
            let green = startingValues.green + (CGFloat(timeDifference) * difference.green)
            
            
            let borderWidth = width + ((CIRCLE_WIDTH_HEIGHT - 5) * CGFloat(timeDifference))
            print("Border Width: ", borderWidth)
            
            let circleRect = CGRect(x: point.x - (borderWidth/2), y: point.y - (borderWidth/2), width: borderWidth, height: borderWidth)
            circleLayer.path = UIBezierPath(roundedRect: circleRect, cornerRadius: borderWidth/2).cgPath
            circleLayer.fillColor = UIColor(red: red, green: green, blue: blue, alpha: 1).cgColor
            circleLayer.needsLayout()

        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.backgroundColor = UIColor.clear
        setNeedsDisplay()
    }
    
    private func schedulePointRemoval() {
        let date = Date().addingTimeInterval(TIME_INTERVAL)
        let timer = Timer(fireAt: date, interval: TIME_INTERVAL, target: self, selector: #selector(removePoint), userInfo: nil, repeats: false)
        RunLoop.main.add(timer, forMode: .commonModes)
    }
    
    private func scheduleBezierRemoval() {
        let date = Date().addingTimeInterval(BEZIER_POINT_INTERVAL)
        let timer = Timer(fireAt: date, interval: BEZIER_POINT_INTERVAL, target: self, selector: #selector(removeBezierPoint), userInfo: nil, repeats: false)
        RunLoop.main.add(timer, forMode: .commonModes)
    }
    
    @objc private func removeBezierPoint(timer: Timer){
        timer.invalidate()
        touchPoints.removeFirst()
        redrawBezier()
    }
    
    @objc private func removePoint(timer: Timer){
        if let drawPoint = drawPoints.first {
            
            drawPoint.shape.removeFromSuperlayer()
            drawPoints.removeFirst()
            if firstPoint != nil { firstPoint = nil }
        }
        if drawPoints.isEmpty {
            circleLayer.removeFromSuperlayer()
        }
        timer.invalidate()
    }
    
    private func redrawBezier() {
        if touchPoints.isEmpty { return }
        
        let bezierPath = UIBezierPath()
        bezierPath.lineCapStyle = .round
        bezierPath.lineJoinStyle = .round
        bezierPath.miterLimit = 15
        bezierPath.interpolatePointsWithHermite(interpolationPoints: touchPoints)
        drawLayer.path = bezierPath.cgPath
    }
    
    private func redraw(){
        let pointInfo = getBezierPaths(fromPoints: waitingPoints)
        
        for path in pointInfo.bezierPaths {
            let drawPoint = DrawPoint(bezierPath: path)
            if firstPoint == nil { firstPoint = drawPoint }
            layer.addSublayer(drawPoint.shape)
            drawPoints.append(drawPoint)
            schedulePointRemoval()
        }
        
        if let points = pointInfo.allPoints.last {
            waitingPoints.removeAll()
            if points.count > 2 {
                for (index, point) in points.enumerated() {
                    if index == pointInfo.allPoints.count - 1 {
                        waitingPoints.append(point)
                    } else if index == pointInfo.allPoints.count - 2, let point = points.last{
                        waitingPoints.append(point)
                    }
                }
            } else { waitingPoints.append(contentsOf: points) }
        } else { waitingPoints.removeAll() }
    }
    
    public func addPointAndRedraw(_ points: [CGPoint], touchDidEnd: Bool) {
        waitingPoints.append(contentsOf: points)
        allPoints.append(contentsOf: points)
        touchPoints.append(contentsOf: points)
        
        redrawBezier()
        points.forEach({ _ in scheduleBezierRemoval()})
        
        if waitingPoints.count >= 2{
            redraw()
        }
        
        if let point = points.last {
            let circleRect = CGRect(x: point.x - (CIRCLE_WIDTH_HEIGHT/2), y: point.y - (CIRCLE_WIDTH_HEIGHT/2), width: CIRCLE_WIDTH_HEIGHT, height: CIRCLE_WIDTH_HEIGHT)
            circleLayer.path = UIBezierPath(roundedRect: circleRect, cornerRadius: CIRCLE_WIDTH_HEIGHT/2).cgPath
        }
        
        if touchDidEnd {
            self.touchEnded = Date()
        }
    }
    
}

fileprivate extension CanvasView {
    func getBezierPaths(fromPoints interpolationPoints: [CGPoint], alpha: CGFloat = 1.0/3.0) -> (bezierPaths: [UIBezierPath], allPoints: [[CGPoint]]){
        var bezierPaths = [UIBezierPath]()
        var allPoints = [[CGPoint]]()
        print("points: ", interpolationPoints.count)
        
        let n = interpolationPoints.count - 1
        
        for index in 0..<n
        {
            let bezierPath = UIBezierPath()
            bezierPath.lineCapStyle = .round
            bezierPath.lineJoinStyle = .round
            bezierPath.miterLimit = 15
            
            var currentPoint = interpolationPoints[index]
            bezierPath.move(to: currentPoint)
            var nextIndex = (index + 1) % interpolationPoints.count
            var prevIndex = index == 0 ? interpolationPoints.count - 1 : index - 1
            var previousPoint = interpolationPoints[prevIndex]
            var nextPoint = interpolationPoints[nextIndex]
            let endPoint = nextPoint
            var mx : CGFloat
            var my : CGFloat
            
            if index > 0
            {
                mx = (nextPoint.x - previousPoint.x) / 2.0
                my = (nextPoint.y - previousPoint.y) / 2.0
            }
            else
            {
                mx = (nextPoint.x - currentPoint.x) / 2.0
                my = (nextPoint.y - currentPoint.y) / 2.0
            }
            
            let controlPoint1 = CGPoint(x: currentPoint.x + mx * alpha, y: currentPoint.y + my * alpha)
            currentPoint = interpolationPoints[nextIndex]
            nextIndex = (nextIndex + 1) % interpolationPoints.count
            prevIndex = index
            previousPoint = interpolationPoints[prevIndex]
            nextPoint = interpolationPoints[nextIndex]
            
            if index < n - 1
            {
                mx = (nextPoint.x - previousPoint.x) / 2.0
                my = (nextPoint.y - previousPoint.y) / 2.0
            }
            else
            {
                mx = (currentPoint.x - previousPoint.x) / 2.0
                my = (currentPoint.y - previousPoint.y) / 2.0
            }
            
            let controlPoint2 = CGPoint(x: currentPoint.x - mx * alpha, y: currentPoint.y - my * alpha)
            if index + 1 != n{
                bezierPath.addCurve(to: endPoint, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
                allPoints.append([endPoint, controlPoint1, controlPoint2])
            } else {
                bezierPath.addLine(to: currentPoint)
                allPoints.append([previousPoint, currentPoint])
            }
            bezierPaths.append(bezierPath)
        }
        return (bezierPaths: bezierPaths, allPoints: allPoints)
    }
}

fileprivate extension UIBezierPath
{
    func interpolatePointsWithHermite(interpolationPoints : [CGPoint], alpha : CGFloat = 1.0/3.0)
    {
        guard !interpolationPoints.isEmpty else { return }
        self.move(to: interpolationPoints[0])
        
        let n = interpolationPoints.count - 1
        
        for index in 0..<n
        {
            var currentPoint = interpolationPoints[index]
            var nextIndex = (index + 1) % interpolationPoints.count
            var prevIndex = index == 0 ? interpolationPoints.count - 1 : index - 1
            var previousPoint = interpolationPoints[prevIndex]
            var nextPoint = interpolationPoints[nextIndex]
            let endPoint = nextPoint
            var mx : CGFloat
            var my : CGFloat
            
            if index > 0
            {
                mx = (nextPoint.x - previousPoint.x) / 2.0
                my = (nextPoint.y - previousPoint.y) / 2.0
            }
            else
            {
                mx = (nextPoint.x - currentPoint.x) / 2.0
                my = (nextPoint.y - currentPoint.y) / 2.0
            }
            
            let controlPoint1 = CGPoint(x: currentPoint.x + mx * alpha, y: currentPoint.y + my * alpha)
            currentPoint = interpolationPoints[nextIndex]
            nextIndex = (nextIndex + 1) % interpolationPoints.count
            prevIndex = index
            previousPoint = interpolationPoints[prevIndex]
            nextPoint = interpolationPoints[nextIndex]
            
            if index < n - 1
            {
                mx = (nextPoint.x - previousPoint.x) / 2.0
                my = (nextPoint.y - previousPoint.y) / 2.0
            }
            else
            {
                mx = (currentPoint.x - previousPoint.x) / 2.0
                my = (currentPoint.y - previousPoint.y) / 2.0
            }
            
            let controlPoint2 = CGPoint(x: currentPoint.x - mx * alpha, y: currentPoint.y - my * alpha)
            
            self.addCurve(to: endPoint, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
        }
    }
}
