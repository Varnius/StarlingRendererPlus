// StarlingRendererPlus
// Copyright Simonas Pauliukevičius. All Rights Reserved.
//
// This program is free software. You can redistribute and/or modify it
// in accordance with the terms of the accompanying license agreement.

package starling.extensions.rendererPlus.rendering
{
    import starling.rendering.MeshEffect;
    import starling.rendering.MeshStyle;

    public class OccluderStyle extends MeshStyle
    {
        override public function createEffect():MeshEffect
        {
            return new OccluderEffect();
        }

        override public function canBatchWith(meshStyle:MeshStyle):Boolean
        {
            if(meshStyle is OccluderStyle)
            {
                return super.canBatchWith(meshStyle);
            }
            else return false;
        }
    }
}
