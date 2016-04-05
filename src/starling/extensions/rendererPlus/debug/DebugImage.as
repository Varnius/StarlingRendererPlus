// StarlingRendererPlus
// Copyright Simonas Pauliukevičius. All Rights Reserved.
//
// This program is free software. You can redistribute and/or modify it
// in accordance with the terms of the accompanying license agreement.

package starling.extensions.rendererPlus.debug
{
    import starling.display.Image;
    import starling.textures.Texture;

    public class DebugImage extends Image
    {
        public function DebugImage(texture:Texture)
        {
            super(texture);
            style = new DebugImageStyle();
        }
    }
}
