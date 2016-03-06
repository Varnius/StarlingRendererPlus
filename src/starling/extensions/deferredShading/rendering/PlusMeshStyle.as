package starling.extensions.deferredShading.rendering
{
    import starling.rendering.MeshEffect;
    import starling.rendering.MeshStyle;
    import starling.rendering.RenderState;
    import starling.textures.Texture;

    public class PlusMeshStyle extends MeshStyle
    {
        public function PlusMeshStyle()
        {
            super();
        }

        override public function copyFrom(meshStyle:MeshStyle):void
        {
            var plusMeshStyle:PlusMeshStyle = meshStyle as PlusMeshStyle;

            // copy here

            super.copyFrom(meshStyle);
        }

        override public function createEffect():MeshEffect
        {
            return new PlusMeshEffect();
        }

        override public function updateEffect(effect:MeshEffect, state:RenderState):void
        {
            // ..

            super.updateEffect(effect, state);
        }

        override public function canBatchWith(meshStyle:MeshStyle):Boolean
        {
            // PlushMeshStyle should be able to batch with simple MeshStyles because
            // all additional textures (normal, depth etc) are supposed to have the
            // same properties as the main texture set at sampler #0
            if(meshStyle is MeshStyle)
            {
                var newTexture:Texture = meshStyle.texture;

                if(texture == null && newTexture == null) return true;
                else if(texture && newTexture)
                    return texture.base == newTexture.base &&
                            textureSmoothing == meshStyle.textureSmoothing;
                else return false;
            }
            else return false;
        }
    }
}
