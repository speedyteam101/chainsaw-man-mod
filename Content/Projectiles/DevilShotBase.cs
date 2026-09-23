using Microsoft.Xna.Framework;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Projectiles
{
	// Shared behaviour for hostile shots fired by devils.
	// ai[0] == 1 makes the shot affected by gravity.
	public abstract class DevilShotBase : ModProjectile
	{
		protected abstract int DustType { get; }
		protected virtual int Size => 14;
		protected virtual int DebuffType => -1;
		protected virtual bool Spins => true;

		public override void SetDefaults() {
			Projectile.width = Size;
			Projectile.height = Size;
			Projectile.friendly = false;
			Projectile.hostile = true;
			Projectile.tileCollide = true;
			Projectile.ignoreWater = true;
			Projectile.penetrate = 1;
			Projectile.timeLeft = 300;
			Projectile.aiStyle = -1;
			CooldownSlot = ImmunityCooldownID.Bosses;
		}

		public override void AI() {
			if (Spins) {
				Projectile.rotation += 0.3f;
			}
			else {
				Projectile.rotation = Projectile.velocity.ToRotation();
			}

			if (Projectile.ai[0] == 1f) {
				Projectile.velocity.Y += 0.2f;
			}

			if (Main.rand.NextBool(2)) {
				Dust dust = Dust.NewDustDirect(Projectile.position, Projectile.width, Projectile.height, DustType);
				dust.noGravity = true;
				dust.velocity *= 0.3f;
			}
		}

		public override void OnHitPlayer(Player target, Player.HurtInfo info) {
			if (DebuffType >= 0) {
				target.AddBuff(DebuffType, 180);
			}
		}

		public override Color? GetAlpha(Color lightColor) {
			return Color.White;
		}

		public override void OnKill(int timeLeft) {
			for (int i = 0; i < 6; i++) {
				Dust.NewDust(Projectile.position, Projectile.width, Projectile.height, DustType);
			}
		}
	}
}
