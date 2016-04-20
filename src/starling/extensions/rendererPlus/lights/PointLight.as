// StarlingRendererPlus
// Copyright Simonas Pauliukevičius. All Rights Reserved.
//
// This program is free software. You can redistribute and/or modify it
// in accordance with the terms of the accompanying license agreement.

package starling.extensions.rendererPlus.lights
{
    import flash.geom.Point;
    import flash.geom.Rectangle;

    import starling.extensions.rendererPlus.RenderPass;
    import starling.extensions.rendererPlus.display.RendererPlus;
    import starling.extensions.rendererPlus.lights.rendering.PointLightEffect;
    import starling.extensions.rendererPlus.lights.rendering.PointLightStyle;
    import starling.extensions.rendererPlus.renderer_internal;
    import starling.rendering.IndexData;
    import starling.rendering.Painter;
    import starling.rendering.VertexData;

    use namespace renderer_internal;

    /**
     * Omnidirectional light.
     */
    public class PointLight extends Light
    {
        private var _mNumEdges:int = 8;
        private static var tmpBounds:Rectangle = new Rectangle();
        private static var center:Point = new Point();

        public function PointLight()
        {
            var vertexData:VertexData = new VertexData(PointLightEffect.VERTEX_FORMAT);
            var indexData:IndexData = new IndexData(24);
            var style:PointLightStyle = new PointLightStyle();

            super(vertexData, indexData, style);
            style.light = this;
            setupVertices();
        }

        override public function render(painter:Painter):void
        {
            if(RendererPlus.renderPass == RenderPass.LIGHTS)
            {
                var style:PointLightStyle = this.style as PointLightStyle;
                var numVertices:int = vertexData.numVertices;

                getBounds(null, tmpBounds);
                var scaledRadius:Number = tmpBounds.width / 2;

                center.setTo(0, 0);
                localToGlobal(center, center);

                for(var i:int = 0; i < numVertices; ++i)
                {
                    vertexData.setPoint3D(i, 'lightColor', style._colorR, style._colorG, style._colorB);
                    vertexData.setPoint3D(i, 'lightPosition', center.x, center.y, style.radius / 2);
                    vertexData.setPoint4D(i, 'lightProps', scaledRadius, style.strength, 1 / scaledRadius, scaledRadius * scaledRadius);
                    vertexData.setFloat(i, 'castsShadows', style.castsShadows ? 1.0 : 0.0);
                    vertexData.setPoint3D(i, 'attenuation', style.attenuation, 1 / (style.attenuation + 1), 1 - (1 / (style.attenuation + 1)));
                }

                super.render(painter);
            }
        }

        public function setupVertices():void
        {
            this.vertexData.clear();
            this.indexData.clear();

            var i:int;
            var vertexData:VertexData = this.vertexData;
            var indexData:IndexData = this.indexData;

            //            indexData.numIndices = mNumEdges * 3;
            //            vertexData.numVertices = mNumEdges + 1;

            for(i = 0; i < _mNumEdges; ++i)
            {
                var edge:Point = Point.polar((style as PointLightStyle).excircleRadius, (i * 2 * Math.PI) / _mNumEdges + 22.5 * Math.PI / 180);
                vertexData.setPoint(i, 'position', edge.x, edge.y);
            }

            // Center vertex
            vertexData.setPoint(_mNumEdges, 'position', 0.0, 0.0);

            // Fill index data for triangles

            for(i = 0; i < _mNumEdges; ++i)
                indexData.addTriangle(_mNumEdges, i, (i + 1) % _mNumEdges);

            setRequiresRedraw();
        }

        override public function set rotation(value:Number):void {}
    }
}