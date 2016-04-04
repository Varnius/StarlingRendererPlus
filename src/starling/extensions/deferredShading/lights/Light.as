package starling.extensions.deferredShading.lights
{
    import starling.display.Mesh;
    import starling.extensions.deferredShading.RenderPass;
    import starling.extensions.deferredShading.display.RendererPlus;
    import starling.extensions.deferredShading.renderer_internal;
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