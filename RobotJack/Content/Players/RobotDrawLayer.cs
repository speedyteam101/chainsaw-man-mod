using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using RobotJack.Common;
using Terraria;
using Terraria.DataStructures;
using Terraria.ModLoader;

namespace RobotJack.Content.Players
{
	// Draws the robot in place of the normal player body while transformed.
	// The sheets use the same 20-frame layout as the vanilla player sheet, so the game's own
	// legFrame and bodyFrame pick the pose (walking, jumping, aiming the arm while using an item).
	// RobotJackPlayer.HideDrawLayers hides the vanilla body layers at the same time.
	public class RobotDrawLayer : PlayerDrawLayer
	{
		private const string Path = "RobotJack/Content/Players/";

		public override bool GetDefaultVisibility(PlayerDrawSet drawInfo) {
			Player player = drawInfo.drawPlayer;
			return !player.dead && player.GetModPlayer<RobotJackPlayer>().Transformed;
		}

		public override Position GetDefaultPosition() => new Between(PlayerDrawLayers.Torso, PlayerDrawLayers.OffhandAcc);

		protected override void Draw(ref PlayerDrawSet drawInfo) {
			Player player = drawInfo.drawPlayer;

			Point tile = (drawInfo.Center / 16f).ToPoint();
			Color light = Lighting.GetColor(tile.X, tile.Y) * (1f - drawInfo.shadow);
			Color glow = Color.White * (1f - drawInfo.shadow);

			// Legs first, then body on top, each with a full-bright glow pass (visor, chest core, jets).
			DrawPart(ref drawInfo, "RobotLegs", player.legFrame, player.legPosition, player.legRotation, light);
			DrawPart(ref drawInfo, "RobotLegs_Glow", player.legFrame, player.legPosition, player.legRotation, glow);
			DrawPart(ref drawInfo, "RobotBody", player.bodyFrame, player.bodyPosition, player.bodyRotation, light);
			DrawPart(ref drawInfo, "RobotBody_Glow", player.bodyFrame, player.bodyPosition, player.bodyRotation, glow);
		}

		// Same placement vanilla uses for the player's body and legs.
		private static void DrawPart(ref PlayerDrawSet drawInfo, string texture, Rectangle frame, Vector2 offset, float rotation, Color color) {
			Player player = drawInfo.drawPlayer;
			Texture2D tex = ModContent.Request<Texture2D>(Path + texture).Value;

			// The robot sheets are always 40x56 per frame, like the vanilla sheet.
			int frameIndex = frame.Height > 0 ? frame.Y / frame.Height : 0;
			frameIndex = System.Math.Clamp(frameIndex, 0, 19);
			Rectangle source = new Rectangle(0, frameIndex * 56, 40, 56);

			Vector2 position = new Vector2(
				(int)(drawInfo.Position.X - Main.screenPosition.X - 20 + player.width / 2),
				(int)(drawInfo.Position.Y - Main.screenPosition.Y + player.height - 56 + 4))
				+ offset + new Vector2(20, 28);

			drawInfo.DrawDataCache.Add(new DrawData(tex, position, source, color, rotation, new Vector2(20, 28), 1f, drawInfo.playerEffect, 0));
		}
	}
}
