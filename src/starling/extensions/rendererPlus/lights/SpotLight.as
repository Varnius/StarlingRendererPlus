// StarlingRendererPlus
// Copyright Simonas Pauliukevičius. All Rights Reserved.
//
// This program is free software. You can redistribute and/or modify it
// in accordance with the terms of the accompanying license agreement.

package starling.extensions.rendererPlus.lights
{
    import flash.geom.Matrix;
    import flash.geom.Point;
    import flash.geom.Rectangle;

    import starling.display.DisplayObject;
    import starling.extensions.rendererPlus.RenderPass;
    import starling.extensions.rendererPlus.display.RendererPlus;
    import starling.extensions.rendererPlus.lights.rendering.SpotLightEffect;
    import starling.extensions.rendererPlus.lights.rendering.SpotLightStyle;
    import starling.extensions.rendererPlus.renderer_internal;
    import starling.rendering.IndexData;
    import starling.rendering.Painter;
    import starling.rendering.VertexData;

    use namespace renderer_internal;

    /**
     * Spotlight.
     */
    public class SpotLight extends Light
    {
        private static var _helperMatrix:Matrix = new Matrix();
        private var _bounds:Rectangle = new Rectangle();
        private var _numEdges:int = 32;
        private var pointA:Point = new Point();
        private var pointB:Point = new Point();

        public function SpotLight()
        {
            var vertexData:VertexData = new VertexData(SpotLightEffect.VERTEX_FORMAT);
            var indexData:IndexData = new IndexData(24);
            var style:SpotLightStyle = new SpotLightStyle();

            super(vertexData, indexData, style);
            style.light = this;
            setupVertices();
        }

        override public function render(painter:Painter):void
        {
            if(RendererPlus.renderPass == RenderPass.LIGHTS)
            {
                var style:SpotLightStyle = this.style as SpotLightStyle;

                style.center.setTo(0, 0);
                localToGlobal(style.center, style.center);
                super.render(painter);
            }
        }

        /**
         * Look at specific point in global (stage) coordinates.
         */
        public function lookAt(point:Point):void
        {
            var style:SpotLightStyle = this.style as SpotLightStyle;

            pointA.setTo(point.x, point.y);
            pointB.setTo(x, y);
            parent.localToGlobal(pointB, pointB);
            pointA.setTo(pointA.x - pointB.x, pointA.y - pointB.y);

            var atan2:Number = Math.atan2(-pointA.y, pointA.x);
            rotation = -(atan2 < 0 ? Math.PI * 2 + atan2 : atan2) - style.angle / 2;
        }

        public function setupVertices():void
        {
            this.vertexData.clear();
            this.indexData.clear();

            var i:int;
            var vertexData:VertexData = this.vertexData;
            var indexData:IndexData = this.indexData;
            var style:SpotLightStyle = this.style as SpotLightStyle;

            //            indexData.numIndices = mNumEdges * 3;
            //            vertexData.numVertices = mNumEdges + 1;

            for(i = 0; i < _numEdges; ++i)
            {
                var edge:Point = Point.polar(style.excircleRadius, style.angle * (i / (_numEdges - 1)));
                vertexData.setPoint(i, 'position', edge.x, edge.y);
            }

            // Center vertex
            vertexData.setPoint(_numEdges, 'position', 0.0, 0.0);

            // Fill index data for triangles

            for(i = 0; i < _numEdges - 1; ++i)
                indexData.addTriangle(_numEdges, i, (i + 1) % _numEdges);

            setRequiresRedraw();
        }

        /** @inheritDoc */
        public override function getBounds(targetSpace:DisplayObject, out:Rectangle = null):Rectangle
        {
            if(out == null) out = new Rectangle();

            var transformationMatrix:Matrix = targetSpace == this ?
                    null : getTransformationMatrix(targetSpace, _helperMatrix);

            return vertexData.getBounds('position', transformationMatrix, 0, -1, out);
        }

        /** @inheritDoc */
        override public function hitTest(localPoint:Point):DisplayObject
        {
            if(!visible || !touchable || !hitTestMask(localPoint)) return null;
            else if(_bounds.containsPoint(localPoint)) return this;
            else return null;
        }
    }
}