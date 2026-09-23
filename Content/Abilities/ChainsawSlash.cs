using Microsoft.Xna.Framework;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Abilities
{
	// Tier 1: big, fast swings with the arm chainsaws.
	public class ChainsawSlash : DevilAbility
	{
		public override int RequiredTier => 1;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.width = 48;
			Item.height = 48;
			Item.scale = 1.5f;
			Item.useStyle = ItemUseStyleID.Swing;
			Item.useTime = 16;
			Item.useAnimation = 16;
			Item.autoReuse = true;
			Item.DamageType = DamageClass.Melee;
			Item.damage = 55;
			Item.crit = 10;
			Item.knockBack = 6f;
			Item.UseSound = SoundID.Item22;
		}

		public override void MeleeEffects(Player player, Rectangle hitbox) {
			if (Main.rand.NextBool(2)) {
				Dust.NewDust(new Vector2(hitbox.X, hitbox.Y), hitbox.Width, hitbox.Height, DustID.Blood);
			}
		}

		public override void OnHitNPC(Player player, NPC target, NPC.HitInfo hit, int damageDone) {
			target.AddBuff(BuffID.Ichor, 180);
		}
	}
}
