// StarlingRendererPlus
// Copyright Simonas Pauliukevičius. All Rights Reserved.
//
// This program is free software. You can redistribute and/or modify it
// in accordance with the terms of the accompanying license agreement.

package starling.extensions.rendererPlus.lights
{
    import flash.geom.Point;

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

                style.center.setTo(0, 0);
                localToGlobal(style.center, style.center);
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
    }
}