// StarlingRendererPlus
// Copyright Simonas Pauliukevičius. All Rights Reserved.
//
// This program is free software. You can redistribute and/or modify it
// in accordance with the terms of the accompanying license agreement.

package starling.extensions.rendererPlus.lights
{
    import starling.display.Mesh;
    import starling.extensions.rendererPlus.RenderPass;
    import starling.extensions.rendererPlus.display.RendererPlus;
    import starling.extensions.rendererPlus.renderer_internal;
    import starling.rendering.IndexData;
    import starling.rendering.MeshStyle;
    import starling.rendering.Painter;
    import starling.rendering.VertexData;

    use namespace renderer_internal;

    /**
     * Base for all types of lights.
     * Use one of the subclasses instead.
     */
    public class Light extends Mesh
    {
        public function Light(vertexData:VertexData, indexData:IndexData, style:MeshStyle)
        {
            super(vertexData, indexData, style);
        }

        override public function render(painter:Painter):void
        {
            if(RendererPlus.renderPass == RenderPass.LIGHTS) super.render(painter);
        }
    }
}