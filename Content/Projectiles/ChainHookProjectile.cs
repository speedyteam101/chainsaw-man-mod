using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Terraria;
using Terraria.GameContent;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Projectiles
{
	// Chain fired by the Chain Hook ability. Flies out, and when it hits an enemy or a block it pulls the player there.
	public class ChainHookProjectile : ModProjectile
	{
		private const string ChainTexturePath = "ChainsawManMod/Content/Projectiles/ChainHookChain";
		private const int MaxFlightTicks = 30;
		private const float PullSpeed = 20f;

		// ai[0]: 0 = flying out, 1 = pulling the player, 2 = retracting
		private ref float State => ref Projectile.ai[0];
		private ref float Timer => ref Projectile.ai[1];

		public override void SetDefaults() {
			Projectile.width = 14;
			Projectile.height = 14;
			Projectile.friendly = true;
			Projectile.DamageType = DamageClass.Melee;
			Projectile.penetrate = -1;
			Projectile.tileCollide = true;
			Projectile.timeLeft = 180;
			Projectile.usesLocalNPCImmunity = true;
			Projectile.localNPCHitCooldown = -1; // each enemy is hit once per throw
			Projectile.aiStyle = -1;
		}

		public override void AI() {
			Player player = Main.player[Projectile.owner];
			if (player.dead || !player.active) {
				Projectile.Kill();
				return;
			}

			Timer++;
			Vector2 toPlayer = player.Center - Projectile.Center;
			Projectile.rotation = (-toPlayer).ToRotation();

			if (State == 0f && Timer >= MaxFlightTicks) {
				State = 2f; // missed: retract
			}

			if (State == 1f) {
				// Pull the player to the hook.
				Projectile.velocity = Vector2.Zero;
				Projectile.tileCollide = false;
				if (Main.myPlayer == Projectile.owner) {
					player.velocity = (-toPlayer).SafeNormalize(Vector2.Zero) * PullSpeed;
					player.fallStart = (int)(player.position.Y / 16f);
				}
				if (toPlayer.Length() < 40f || Timer > 40) {
					Projectile.Kill();
				}
			}
			else if (State == 2f) {
				Projectile.tileCollide = false;
				Projectile.friendly = false;
				Projectile.velocity = toPlayer.SafeNormalize(Vector2.Zero) * 28f;
				if (toPlayer.Length() < 30f) {
					Projectile.Kill();
				}
			}
		}

		private void StartPull() {
			State = 1f;
			Timer = 0f;
			Projectile.netUpdate = true;
		}

		public override void OnHitNPC(NPC target, NPC.HitInfo hit, int damageDone) {
			if (State == 0f) {
				Projectile.Center = target.Center;
				StartPull();
			}
			for (int i = 0; i < 6; i++) {
				Dust.NewDust(target.position, target.width, target.height, DustID.Blood);
			}
		}

		public override bool OnTileCollide(Vector2 oldVelocity) {
			if (State == 0f) {
				StartPull();
			}
			return false; // keep the projectile alive
		}

		public override bool PreDraw(ref Color lightColor) {
			Player player = Main.player[Projectile.owner];
			Texture2D chain = ModContent.Request<Texture2D>(ChainTexturePath).Value;

			// Draw chain links from the player's hand to the hook.
			Vector2 start = player.MountedCenter;
			Vector2 end = Projectile.Center;
			Vector2 direction = (end - start).SafeNormalize(Vector2.UnitX);
			float length = Vector2.Distance(start, end);
			float rotation = direction.ToRotation() + MathHelper.PiOver2;
			Vector2 origin = chain.Size() / 2f;

			for (float d = 0f; d < length; d += chain.Height) {
				Vector2 position = start + direction * d;
				Point tile = (position / 16f).ToPoint();
				Main.EntitySpriteDraw(chain, position - Main.screenPosition, null, Lighting.GetColor(tile.X, tile.Y), rotation, origin, 1f, SpriteEffects.None, 0);
			}

			// Draw the hook head.
			Texture2D hook = TextureAssets.Projectile[Type].Value;
			Main.EntitySpriteDraw(hook, Projectile.Center - Main.screenPosition, null, lightColor, Projectile.rotation, hook.Size() / 2f, 1f, SpriteEffects.None, 0);
			return false;
		}
	}
}
