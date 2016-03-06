/**
 * Created by Derpy on 2016.02.21.
 */
package starling.extensions.deferredShading.debug
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
