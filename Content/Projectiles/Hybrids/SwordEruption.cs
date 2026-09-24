using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Terraria;
using Terraria.GameContent;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Projectiles.Hybrids
{
	// Sword form: blades burst up out of the ground, then sink back down.
	public class SwordEruption : ModProjectile
	{
		private const int Lifetime = 30;

		public override void SetDefaults() {
			Projectile.width = 60;
			Projectile.height = 100;
			Projectile.friendly = true;
			Projectile.DamageType = DamageClass.Generic;
			Projectile.penetrate = -1;
			Projectile.timeLeft = Lifetime;
			Projectile.tileCollide = false;
			Projectile.ignoreWater = true;
			Projectile.usesLocalNPCImmunity = true;
			Projectile.localNPCHitCooldown = -1;
			Projectile.aiStyle = -1;
		}

		public override void AI() {
			if (Projectile.ai[0] == 0f) {
				Projectile.ai[0] = 1f;
				for (int i = 0; i < 15; i++) {
					Dust.NewDust(Projectile.BottomLeft - new Vector2(0f, 8f), Projectile.width, 8, DustID.Silver, 0f, -4f);
				}
			}
		}

		public override bool PreDraw(ref Color lightColor) {
			Texture2D texture = TextureAssets.Projectile[Type].Value;
			// Rise quickly, hold, then sink.
			float age = Lifetime - Projectile.timeLeft;
			float rise = age < 6 ? age / 6f : Projectile.timeLeft < 8 ? Projectile.timeLeft / 8f : 1f;
			int visible = (int)(texture.Height * rise);
			if (visible <= 0) {
				return false;
			}
			Rectangle source = new Rectangle(0, 0, texture.Width, visible);
			Vector2 bottom = Projectile.Bottom - Main.screenPosition;
			Main.EntitySpriteDraw(texture, bottom, source, lightColor, 0f, new Vector2(texture.Width / 2f, visible), 1f, SpriteEffects.None, 0);
			return false;
		}
	}
}
