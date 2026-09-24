using ChainsawManMod.Common.Players;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Terraria;
using Terraria.DataStructures;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Players
{
	// Draws the form's sprite (Chainsaw Man or a hybrid) in place of the normal player body while transformed.
	// ChainsawManPlayer.HideDrawLayers hides the vanilla body layers at the same time.
	public class ChainsawDevilDrawLayer : PlayerDrawLayer
	{
		// The sprites are small, so draw them a bit bigger to roughly match the normal player's height.
		public const float SpriteScale = 1.4f;

		public override bool GetDefaultVisibility(PlayerDrawSet drawInfo) {
			Player player = drawInfo.drawPlayer;
			return !player.dead && player.GetModPlayer<ChainsawManPlayer>().AnyForm;
		}

		public override Position GetDefaultPosition() => new Between(PlayerDrawLayers.Torso, PlayerDrawLayers.OffhandAcc);

		protected override void Draw(ref PlayerDrawSet drawInfo) {
			Player player = drawInfo.drawPlayer;
			ChainsawManPlayer modPlayer = player.GetModPlayer<ChainsawManPlayer>();
			// Chainsaw Man: tier 3 uses the Hero of Hell sheet, lower tiers the Chainsaw Devil sheet. Hybrids have their own.
			DevilSheet sheet = modPlayer.CurrentSheet;
			Texture2D texture = ModContent.Request<Texture2D>(sheet.TexturePath).Value;

			// Anchor the bottom centre of the frame to the player's feet.
			Vector2 feet = drawInfo.Center + new Vector2(0f, player.height / 2f) - Main.screenPosition;
			feet = new Vector2((int)feet.X, (int)feet.Y);

			Point tile = (drawInfo.Center / 16f).ToPoint();
			Color color = Lighting.GetColor(tile.X, tile.Y) * (1f - drawInfo.shadow);

			SpriteEffects effects = player.direction == -1 ? SpriteEffects.FlipHorizontally : SpriteEffects.None;

			drawInfo.DrawDataCache.Add(new DrawData(
				texture,
				feet,
				sheet.GetFrame(modPlayer.devilAnim, modPlayer.devilFrame),
				color,
				0f,
				new Vector2(sheet.CellWidth / 2f, sheet.CellHeight),
				SpriteScale,
				effects,
				0
			));
		}
	}
}
