import UIKit

class DemoView: UIView {
    
    var canvasView: CanvasView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        let points = touches.map { (touch) -> CGPoint in
            return touch.location(in: self)
        }
        
        let canvasFrame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        canvasView = CanvasView(frame: canvasFrame, withPoints: points)
        addSubview(canvasView)
        
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let points = touches.map { (touch) -> CGPoint in
            return touch.location(in: self)
        }
        canvasView.addPointAndRedraw(points, touchDidEnd: false)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let points = touches.map { (touch) -> CGPoint in
            return touch.location(in: self)
        }
        canvasView.addPointAndRedraw(points, touchDidEnd: true)
       
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
