using Microsoft.Xna.Framework;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Projectiles
{
	// Spinning chainsaw blade that orbits the player (Chainsaw Storm ability). ai[0] is its starting angle.
	public class StormBlade : ModProjectile
	{
		private const float Radius = 100f;

		public override void SetDefaults() {
			Projectile.width = 40;
			Projectile.height = 40;
			Projectile.friendly = true;
			Projectile.DamageType = DamageClass.Melee;
			Projectile.penetrate = -1;
			Projectile.tileCollide = false;
			Projectile.ignoreWater = true;
			Projectile.timeLeft = 360; // 6 seconds
			Projectile.usesLocalNPCImmunity = true;
			Projectile.localNPCHitCooldown = 10;
			Projectile.aiStyle = -1;
		}

		public override void AI() {
			Player player = Main.player[Projectile.owner];
			if (player.dead || !player.active) {
				Projectile.Kill();
				return;
			}

			Projectile.ai[0] += 0.12f;
			Projectile.Center = player.Center + Projectile.ai[0].ToRotationVector2() * Radius;
			Projectile.rotation += 0.6f;

			if (Main.rand.NextBool(4)) {
				Dust dust = Dust.NewDustDirect(Projectile.position, Projectile.width, Projectile.height, DustID.Torch);
				dust.noGravity = true;
			}
		}

		public override void OnHitNPC(NPC target, NPC.HitInfo hit, int damageDone) {
			target.AddBuff(BuffID.Ichor, 180);
			for (int i = 0; i < 3; i++) {
				Dust.NewDust(target.position, target.width, target.height, DustID.Blood);
			}
		}
	}
}
