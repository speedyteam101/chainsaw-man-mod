using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Terraria;
using Terraria.Audio;
using Terraria.GameContent;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Projectiles
{
	// A floating mass of guns summoned by Makima. Aims at the player (ai[0] = target player index)
	// and fires a stream of bullets, then fades away. It does no contact damage itself.
	public class MakimaGunFiend : ModProjectile
	{
		private const int Lifetime = 110;

		public override void SetDefaults() {
			Projectile.width = 60;
			Projectile.height = 40;
			Projectile.friendly = false;
			Projectile.hostile = false;
			Projectile.tileCollide = false;
			Projectile.ignoreWater = true;
			Projectile.penetrate = -1;
			Projectile.timeLeft = Lifetime;
			Projectile.aiStyle = -1;
			Projectile.alpha = 255;
		}

		public override void AI() {
			Player target = Main.player[(int)Projectile.ai[0]];
			Projectile.ai[1]++;
			float t = Projectile.ai[1];

			// Fade in, fire, fade out.
			if (t < 20) {
				Projectile.alpha = System.Math.Max(0, Projectile.alpha - 13);
			}
			else if (t > Lifetime - 20) {
				Projectile.alpha = System.Math.Min(255, Projectile.alpha + 13);
			}

			Vector2 aim = (target.Center - Projectile.Center).SafeNormalize(Vector2.UnitX);
			Projectile.rotation = aim.ToRotation();

			if (t >= 25 && t < Lifetime - 25 && t % 6 == 0 && Main.netMode != NetmodeID.MultiplayerClient) {
				Vector2 muzzle = Projectile.Center + aim * 50f;
				Projectile.NewProjectile(Projectile.GetSource_FromThis(), muzzle, aim.RotatedByRandom(MathHelper.ToRadians(8f)) * 15f,
					ModContent.ProjectileType<DevilBullet>(), Projectile.damage, 0f, Main.myPlayer);
			}
			if (t >= 25 && t < Lifetime - 25 && t % 6 == 0) {
				SoundEngine.PlaySound(SoundID.Item11, Projectile.Center);
			}
		}

		public override bool PreDraw(ref Color lightColor) {
			Texture2D texture = TextureAssets.Projectile[Type].Value;
			// The guns point right in the art; flip vertically when aiming left so it isn't upside down.
			bool aimingLeft = System.Math.Abs(Projectile.rotation) > MathHelper.PiOver2;
			SpriteEffects effects = aimingLeft ? SpriteEffects.FlipVertically : SpriteEffects.None;
			Main.EntitySpriteDraw(texture, Projectile.Center - Main.screenPosition, null, Color.White * Projectile.Opacity,
				Projectile.rotation, texture.Size() / 2f, 1f, effects, 0);
			return false;
		}
	}
}
