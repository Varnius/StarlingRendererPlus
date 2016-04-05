// StarlingRendererPlus
// Copyright Simonas Pauliukevičius. All Rights Reserved.
//
// This program is free software. You can redistribute and/or modify it
// in accordance with the terms of the accompanying license agreement.

package starling.extensions.rendererPlus.rendering
{
    import starling.rendering.MeshEffect;
    import starling.rendering.MeshStyle;
    import starling.textures.Texture;

    public class PlusMeshStyle extends MeshStyle
    {
        override public function createEffect():MeshEffect
        {
            return new PlusMeshEffect();
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
