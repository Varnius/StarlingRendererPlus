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
            // Should be able to batch with simple MeshStyles because
            // all additional textures (normal, depth etc) are supposed to have the
            // same properties as the main texture set at sampler #0, so - no additional data
            if(meshStyle is MeshStyle)
            {
                return super.canBatchWith(meshStyle);
            }
            else return false;
        }
    }
}
