using Microsoft.Xna.Framework;
using Terraria;
using Terraria.Audio;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Projectiles
{
	// Darkness Devil: a hand of darkness that rises out of the ground under the player after a short warning.
	// Harmless during the warning.
	public class DarkHand : ModProjectile
	{
		private const int WarningTicks = 50;
		private const int GrabTicks = 30;

		public override void SetDefaults() {
			Projectile.width = 40;
			Projectile.height = 90;
			Projectile.friendly = false;
			Projectile.hostile = false;
			Projectile.tileCollide = false;
			Projectile.ignoreWater = true;
			Projectile.penetrate = -1;
			Projectile.timeLeft = WarningTicks + GrabTicks;
			Projectile.aiStyle = -1;
			Projectile.alpha = 255;
			CooldownSlot = ImmunityCooldownID.Bosses;
		}

		public override void AI() {
			Projectile.ai[0]++;
			float t = Projectile.ai[0];

			if (t < WarningTicks) {
				Dust dust = Dust.NewDustDirect(Projectile.BottomLeft - new Vector2(0f, 6f), Projectile.width, 6, DustID.Smoke, 0f, -2f, 100, Color.Black);
				dust.noGravity = true;
				return;
			}

			if (t == WarningTicks) {
				Projectile.hostile = true;
				Projectile.alpha = 0;
				SoundEngine.PlaySound(SoundID.Item8, Projectile.Center);
			}

			if (t > WarningTicks + GrabTicks - 10) {
				Projectile.alpha = System.Math.Min(255, Projectile.alpha + 25);
			}
		}

		public override void OnHitPlayer(Player target, Player.HurtInfo info) {
			target.AddBuff(BuffID.Darkness, 300);
			target.AddBuff(BuffID.Slow, 120);
		}

		public override Color? GetAlpha(Color lightColor) {
			return Color.White * Projectile.Opacity;
		}
	}
}
