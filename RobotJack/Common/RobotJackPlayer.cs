using RobotJack.Content.Abilities;
using RobotJack.Content.Buffs;
using RobotJack.Content.Players;
using Terraria;
using Terraria.DataStructures;
using Terraria.ModLoader;

namespace RobotJack.Common
{
	// Tracks the Robot Jack transformation and hands out the ability items while it's active.
	public class RobotJackPlayer : ModPlayer
	{
		// True while the Robot Form buff is active. Based on the buff itself, so it's correct at any point in the update.
		public bool Transformed => Player.HasBuff(ModContent.BuffType<RobotForm>());

		public override void PostUpdate() {
			if (Player.whoAmI == Main.myPlayer) {
				UpdateAbilityItems();
			}
		}

		// While transformed, the player is given every ability item. When the form ends they are taken away again.
		private void UpdateAbilityItems() {
			bool transformed = Transformed;

			// Remove abilities when not transformed, including one held on the cursor.
			if (!transformed) {
				for (int i = 0; i < Player.inventory.Length; i++) {
					if (Player.inventory[i].ModItem is RobotAbility) {
						Player.inventory[i].TurnToAir();
					}
				}
				if (Main.mouseItem.ModItem is RobotAbility) {
					Main.mouseItem.TurnToAir();
				}
				return;
			}

			foreach (RobotAbility ability in RobotAbility.All) {
				GiveAbility(ability.Type);
			}
		}

		private void GiveAbility(int type) {
			if (Player.HasItem(type) || Main.mouseItem.type == type) {
				return;
			}

			// First empty slot of the main inventory (hotbar first). Coins/ammo slots start at 50.
			for (int i = 0; i < 50; i++) {
				if (Player.inventory[i].IsAir) {
					Player.inventory[i].SetDefaults(type);
					return;
				}
			}
		}

		// While transformed, hide the normal player body so only the robot is drawn.
		// Held items, mounts, wings and debuff effects stay visible.
		public override void HideDrawLayers(PlayerDrawSet drawInfo) {
			if (!Transformed || Player.dead) {
				return;
			}

			PlayerDrawLayer robotLayer = ModContent.GetInstance<RobotDrawLayer>();
			foreach (PlayerDrawLayer layer in PlayerDrawLayerLoader.DrawOrder) {
				if (layer == robotLayer
					|| layer == PlayerDrawLayers.HeldItem
					|| layer == PlayerDrawLayers.ProjectileOverArm
					|| layer == PlayerDrawLayers.Wings
					|| layer == PlayerDrawLayers.MountBack
					|| layer == PlayerDrawLayers.MountFront
					|| layer == PlayerDrawLayers.FrozenOrWebbedDebuff
					|| layer == PlayerDrawLayers.WebbedDebuffBack
					|| layer == PlayerDrawLayers.ElectrifiedDebuffBack
					|| layer == PlayerDrawLayers.ElectrifiedDebuffFront
					|| layer == PlayerDrawLayers.IceBarrier) {
					continue;
				}
				layer.Hide();
			}
		}
	}
}
