// StarlingRendererPlus
// Copyright Simonas Pauliukevičius. All Rights Reserved.
//
// This program is free software. You can redistribute and/or modify it
// in accordance with the terms of the accompanying license agreement.

package starling.extensions.utils
{
	public class ShaderUtils
	{
		public static function joinProgramArray(array:Array):String
		{
			return array.join('\n') + '\n';
		}
	}
}